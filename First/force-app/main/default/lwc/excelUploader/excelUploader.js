import { LightningElement } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import XLSX_LIB from '@salesforce/resourceUrl/xlsx';

export default class ExcelUpload extends LightningElement {

    file;
    xlsxInitialized = false;

    // Full data for future upload
    allExcelData = [];

    // Only preview data
    excelData = [];


    renderedCallback() {

        if (this.xlsxInitialized) {
            return;
        }

        this.xlsxInitialized = true;


        loadScript(this, XLSX_LIB + '/xlsx.full.min.js')
            .then(() => {
                console.log('XLSX Loaded');
            })
            .catch(error => {
                console.error('XLSX Load Error:', error);
            });

    }



    handleFile(event) {

        this.file = event.target.files[0];

        console.log('File Name:', this.file.name);
        console.log('File Size:', this.file.size);

    }


handleSubmit() {

    if (!this.file) {
        alert('Please select a file');
        return;
    }

    const fileName = this.file.name.toLowerCase();
    const reader = new FileReader();

    // ==========================
    // PDF FILE HANDLING
    // ==========================
    if (fileName.endsWith('.pdf')) {

        reader.onload = (e) => {

            const pdfData = e.target.result;

            console.log('PDF Selected');
            console.log('File Name:', this.file.name);
            console.log('File Size:', this.file.size);

            // Store PDF if required
            this.pdfData = pdfData;

            // Clear Excel preview
            this.excelData = [];
            this.allExcelData = [];

            alert('PDF uploaded successfully.');
        };

        reader.readAsArrayBuffer(this.file);
    }

    // ==========================
    // CSV FILE HANDLING
    // ==========================
    else if (fileName.endsWith('.csv')) {

        reader.onload = (e) => {

            try {

                const workbook = XLSX.read(e.target.result, {
                    type: 'string'
                });

                const sheetName = workbook.SheetNames[0];
                const worksheet = workbook.Sheets[sheetName];

                let jsonData = XLSX.utils.sheet_to_json(worksheet, {
                    defval: '',
                    raw: false
                });

                jsonData = jsonData.filter(row =>
                    Object.values(row).some(value =>
                        value !== null &&
                        value !== undefined &&
                        value.toString().trim() !== ''
                    )
                );

                this.allExcelData = jsonData;
                this.excelData = jsonData.slice(0, 100);

            } catch (error) {
                console.error('CSV Error:', error);
            }
        };

        reader.readAsText(this.file);
    }

    // ==========================
    // XLS / XLSX FILE HANDLING
    // ==========================
    else if (
        fileName.endsWith('.xlsx') ||
        fileName.endsWith('.xls')
    ) {

        reader.onload = (e) => {

            try {

                const data = new Uint8Array(e.target.result);

                const workbook = XLSX.read(data, {
                    type: 'array'
                });

                const worksheet =
                    workbook.Sheets[workbook.SheetNames[0]];

                let jsonData = XLSX.utils.sheet_to_json(worksheet, {
                    defval: '',
                    raw: false
                });

                this.allExcelData = jsonData;
                this.excelData = jsonData.slice(0, 100);

            } catch (error) {
                console.error('Excel Error:', error);
            }
        };

        reader.readAsArrayBuffer(this.file);
    }

    // ==========================
    // UNSUPPORTED FILE
    // ==========================
    else {
        alert('Unsupported file type.');
    }
}

}