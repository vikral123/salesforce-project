import { LightningElement, track } from 'lwc';
import getUploadTarget from '@salesforce/apex/PdfTextExtractionService.getUploadTarget';
import startConversion from '@salesforce/apex/PdfTextExtractionService.startConversion';
import checkConversionJob from '@salesforce/apex/PdfTextExtractionService.checkConversionJob';

// The file now uploads directly from the browser to PDF.co's storage via a
// presigned URL (see handleSubmit) - Apex never touches the raw file bytes,
// so the old Apex heap/Aura request-size ceiling that caused
// "aura:systemError" no longer applies to the upload step. PDF.co's
// presigned upload endpoint itself supports files up to 2GB. 15 MB is kept
// here as a product/UX choice, not a platform limit - raise it freely if
// you want to allow larger PDFs.
const SIZE_LIMIT_BYTES = 15 * 1024 * 1024; // 15 MB
const POLL_INTERVAL_MS = 2000;
const MAX_POLL_ATTEMPTS = 150; // ~5 minutes of polling before giving up

export default class PdfTextExtractor extends LightningElement {

    // ---- file state ----
    @track selectedFile = null;
    fileName = '';
    fileSizeLabel = '';
    fileLastModifiedLabel = '';
    isDragOver = false;

    // ---- processing state ----
    @track isProcessing = false;
    @track processingLabel = '';

    // ---- result / message state ----
    @track extractedText = '';
    @track errorMessage = '';
    @track successMessage = '';

    // =====================================================================
    // FILE SELECTION - BROWSE BUTTON
    // =====================================================================

    handleBrowseClick() {
        this.template.querySelector('input.file-input').click();
    }

    handleFileInputChange(event) {
        const file = event.target.files && event.target.files[0];
        if (file) {
            this.processSelectedFile(file);
        }
        event.target.value = '';
    }

    // =====================================================================
    // FILE SELECTION - DRAG AND DROP
    // =====================================================================

    handleDragOver(event) {
        event.preventDefault();
        event.stopPropagation();
        this.isDragOver = true;
    }

    handleDragLeave(event) {
        event.preventDefault();
        event.stopPropagation();
        this.isDragOver = false;
    }

    handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        this.isDragOver = false;

        const files = event.dataTransfer && event.dataTransfer.files;
        if (files && files.length > 0) {
            this.processSelectedFile(files[0]);
        }
    }

    // =====================================================================
    // FILE VALIDATION
    // =====================================================================

    processSelectedFile(file) {
        this.clearMessages();

        const isPdfByType = file.type === 'application/pdf';
        const isPdfByExtension = file.name && file.name.toLowerCase().endsWith('.pdf');

        if (!isPdfByType && !isPdfByExtension) {
            this.errorMessage = `"${file.name}" is not a PDF file. Please select a file with a .pdf extension.`;
            this.selectedFile = null;
            this.fileName = '';
            this.fileSizeLabel = '';
            this.fileLastModifiedLabel = '';
            return;
        }

        this.fileSizeLabel = this.formatFileSize(file.size);
        this.fileLastModifiedLabel = this.formatDate(file.lastModified);

        if (file.size > SIZE_LIMIT_BYTES) {
            this.selectedFile = null;
            this.fileName = file.name;
            this.errorMessage = `"${file.name}" is ${this.fileSizeLabel}, which is over the ${this.formatFileSize(SIZE_LIMIT_BYTES)} limit for this tool. Please use a smaller PDF, or split this one into smaller sections before uploading.`;
            return;
        }

        this.selectedFile = file;
        this.fileName = file.name;
        this.extractedText = '';
    }

    // =====================================================================
    // SUBMIT / EXTRACTION
    //   1. getUploadTarget()  - Apex asks PDF.co for a presigned PUT URL
    //   2. fetch PUT          - browser uploads the raw file directly to
    //                           PDF.co, bypassing Apex/Salesforce entirely
    //   3. startConversion()  - Apex kicks off an async PDF.co job
    //   4. pollJob()          - poll Apex until the job finishes
    // =====================================================================

    async handleSubmit() {
        this.clearMessages();

        if (!this.selectedFile) {
            this.errorMessage = 'Please select a PDF file before submitting.';
            return;
        }

        this.isProcessing = true;
        this.extractedText = '';

        try {
            this.processingLabel = 'Requesting upload URL\u2026';
            const target = await getUploadTarget({ fileName: this.fileName });

            if (target.errorMessage) {
                this.errorMessage = target.errorMessage;
                return;
            }

            this.processingLabel = 'Uploading PDF\u2026';
            const uploadResponse = await fetch(target.presignedUrl, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/octet-stream' },
                body: this.selectedFile
            });

            if (!uploadResponse.ok) {
                throw new Error(
                    `Upload to PDFs.co failed (${uploadResponse.status}). ` +
                    'If this is a CORS error in the browser console, PDF.co\u2019s ' +
                    'storage bucket may need CORS enabled for this domain - contact PDF.co support.'
                );
            }

            this.processingLabel = 'Extracting text\u2026';
            const job = await startConversion({ fileUrl: target.fileUrl });

            if (job.errorMessage) {
                this.errorMessage = job.errorMessage;
                return;
            }

            if (job.extractedText) {
                // Synchronous path: conversion already finished, no job to poll.
                this.extractedText = job.extractedText;
                this.successMessage = `Successfully extracted text from "${this.fileName}".`;
                return;
            }

            if (!job.jobId) {
                this.errorMessage = 'PDF.co did not return extracted text or a job ID.';
                return;
            }

            this.processingLabel = 'Waiting for PDF.co\u2026';
            const finalStatus = await this.pollJob(job.jobId);

            if (finalStatus.errorMessage) {
                this.errorMessage = finalStatus.errorMessage;
            } else {
                this.extractedText = finalStatus.extractedText;
                this.successMessage = `Successfully extracted text from "${this.fileName}".`;
            }
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('PDF extraction error', error);
            const message =
                (error && error.body && error.body.message) ||
                (error && error.message) ||
                'Unknown error';
            this.errorMessage = `Something went wrong while extracting text from this PDF: ${message}`;
        } finally {
            this.isProcessing = false;
            this.processingLabel = '';
        }
    }

    pollJob(jobId) {
        return new Promise((resolve) => {
            let attempts = 0;

            const poll = async () => {
                attempts += 1;
                try {
                    const status = await checkConversionJob({ jobId });

                    if (status.status === 'success') {
                        resolve(status);
                    } else if (status.status === 'failed' || status.status === 'aborted' || status.errorMessage) {
                        resolve(status);
                    } else if (attempts >= MAX_POLL_ATTEMPTS) {
                        resolve({ errorMessage: 'Timed out waiting for PDF.co to finish processing this file.' });
                    } else {
                        // eslint-disable-next-line @lwc/lwc/no-async-operation
                        setTimeout(poll, POLL_INTERVAL_MS);
                    }
                } catch (error) {
                    const message =
                        (error && error.body && error.body.message) ||
                        (error && error.message) ||
                        'Error checking conversion status.';
                    resolve({ errorMessage: message });
                }
            };

            poll();
        });
    }

    // =====================================================================
    // CLEAR
    // =====================================================================

    handleClear() {
        this.selectedFile = null;
        this.fileName = '';
        this.fileSizeLabel = '';
        this.fileLastModifiedLabel = '';
        this.extractedText = '';
        this.clearMessages();
    }

    clearMessages() {
        this.errorMessage = '';
        this.successMessage = '';
    }

    // =====================================================================
    // HELPERS
    // =====================================================================

    formatFileSize(bytes) {
        if (bytes < 1024) {
            return `${bytes} B`;
        }
        if (bytes < 1024 * 1024) {
            return `${(bytes / 1024).toFixed(1)} KB`;
        }
        return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
    }

    formatDate(timestamp) {
        if (!timestamp) {
            return '';
        }
        const date = new Date(timestamp);
        return date.toLocaleString(undefined, {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    // =====================================================================
    // GETTERS FOR TEMPLATE
    // =====================================================================

    get hasSelectedFile() {
        return !!this.selectedFile;
    }

    get hasExtractedText() {
        return !!this.extractedText;
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get hasSuccess() {
        return !!this.successMessage;
    }

    get disableSubmit() {
        return !this.selectedFile || this.isProcessing;
    }

    get dropZoneClass() {
        return this.isDragOver ? 'drop-zone drop-zone_active' : 'drop-zone';
    }

    get progressLabel() {
        return this.processingLabel || 'Processing\u2026';
    }
}