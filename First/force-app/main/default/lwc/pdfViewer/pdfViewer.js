import { LightningElement, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import PDFJS from '@salesforce/resourceUrl/pdfjs';

export default class PdfViewer extends LightningElement {

    pdfLoaded = false;
    pdfDocument = null;

    @track pdfLines = [];
    @track displayData = [];

    totalPdfPages = 0;
    currentPdfPage = 1;

    currentDataPage = 1;
    pageSize = 100;
    totalDataPages = 0;

    renderedCallback() {

        if (this.pdfLoaded) {
            return;
        }

        this.pdfLoaded = true;

        loadScript(this, PDFJS + '/pdfjs/build/pdf.min.js')
            .then(() => {

                window.pdfjsLib.GlobalWorkerOptions.workerSrc =
                    PDFJS + '/pdfjs/build/pdf.worker.min.js';

                console.log('PDF JS Loaded Successfully');

            })
            .catch(error => {

                console.error('Failed to load PDFJS');

                console.error(error);

            });

    }

    handleFile(event) {

        const file = event.target.files[0];

        if (!file) {
            return;
        }

        if (!window.pdfjsLib) {

            console.error('PDFJS not loaded yet');

            return;

        }

        console.log('Selected File:', file.name);
        console.log('File Size:', file.size);
        console.log('File Type:', file.type);

        const reader = new FileReader();

        reader.onload = async () => {

            try {

                console.log('Reading PDF...');

                const typedArray = new Uint8Array(reader.result);

                const loadingTask = window.pdfjsLib.getDocument({
                    data: typedArray
                });

                this.pdfDocument = await loadingTask.promise;

                console.log('PDF Loaded Successfully');
                console.log(this.pdfDocument);

                this.totalPdfPages = this.pdfDocument.numPages;

                console.log('Total PDF Pages:', this.totalPdfPages);

                this.currentPdfPage = 1;

                await this.loadPdfPage();

            }
            catch (error) {

                console.error('PDF ERROR');

                console.error(error);

            }

        };

        reader.readAsArrayBuffer(file);

    }

    async loadPdfPage() {

        try {

            console.log('Loading PDF Page:', this.currentPdfPage);

            const page = await this.pdfDocument.getPage(this.currentPdfPage);

            console.log('Page Loaded');

            const content = await page.getTextContent();

            console.log('TEXT ITEMS COUNT:', content.items.length);

            console.log('FIRST TEXT:', content.items[0]);

            console.log(content);

            this.pdfLines = content.items.map(item => item.str);

            console.log('PDF Lines:', this.pdfLines);

            console.log('Total Lines:', this.pdfLines.length);

            console.log('First 10 Lines:', this.pdfLines.slice(0, 10));

            this.totalDataPages = Math.ceil(
                this.pdfLines.length / this.pageSize
            );

            this.currentDataPage = 1;

            this.load100Records();

        }
        catch (error) {

            console.error('Load Page Error');

            console.error(error);

        }

    }

    load100Records() {

        const start = (this.currentDataPage - 1) * this.pageSize;

        const end = start + this.pageSize;

        this.displayData = [...this.pdfLines.slice(start, end)];

        console.log('Showing Records:', start, end);

        console.log('Display Data:', this.displayData);

    }

    nextDataPage() {

        if (this.currentDataPage < this.totalDataPages) {

            this.currentDataPage++;

            this.load100Records();

        }

    }

    previousDataPage() {

        if (this.currentDataPage > 1) {

            this.currentDataPage--;

            this.load100Records();

        }

    }

    get disableNext() {

        return this.currentDataPage >= this.totalDataPages;

    }

    get disablePrevious() {

        return this.currentDataPage <= 1;

    }

    get hasData() {

        return this.displayData.length > 0;

    }

}