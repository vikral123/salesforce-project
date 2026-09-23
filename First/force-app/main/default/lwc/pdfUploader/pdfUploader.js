import { LightningElement, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import PDFJS from '@salesforce/resourceUrl/pdfjs';

const PAGE_SIZE = 50;
const CHUNK_SIZE = 3;

export default class PdfUploader extends LightningElement {

    pdfJsInitialized = false;
    pdfDocument = null;

    @track pdfData = [];
    @track displayedData = [];

    @track isLoading = false;
    @track progress = 0;

    fileName = '';
    totalPages = 0;

    currentPage = 1;
    totalRecords = 0;


    connectedCallback() {

        console.log('PDF Component Loaded');

    }
renderedCallback() {


    if(this.pdfJsInitialized){
        return;
    }


    this.pdfJsInitialized = true;


    loadScript(
        this,
        PDFJS + '/pdfjs/build/pdf.min.js'
    )
    .then(()=>{


        console.log(
            'PDF JS Loaded Successfully'
        );


        this.pdfjsLib =
            window.pdfjsLib;



        this.pdfjsLib.GlobalWorkerOptions.workerSrc =
            null;



        console.log(
            'PDF Worker Disabled - Salesforce LWC'
        );


    })
    .catch(error=>{


        console.error(
            'PDF JS Loading Error',
            error
        );


    });


}
    handleFileChange(event) {


        const file = event.target.files[0];


        if (!file) {
            return;
        }


        this.fileName = file.name;


        console.log(
            'PDF Name:',
            file.name
        );


        console.log(
            'PDF Size:',
            (file.size / 1024 / 1024).toFixed(2),
            'MB'
        );


        this.selectedFile = file;

    }



    async handleUpload() {


        if (!this.selectedFile) {


            this.showError(
                'Please select PDF file'
            );

            return;

        }



        if (!this.pdfJsInitialized) {


            this.showError(
                'PDF Library not loaded'
            );

            return;

        }



        this.resetData();


        this.isLoading = true;


        try {


            const arrayBuffer =
                await this.readFile(
                    this.selectedFile
                );



            await this.loadPDF(
                arrayBuffer
            );



        }
        catch(error){


            console.error(
                'PDF Processing Error',
                error
            );


            this.showError(
                error.message
            );


        }
        finally{


            this.isLoading = false;


        }



    }



    readFile(file){


        return new Promise(
            (resolve,reject)=>{


                const reader =
                    new FileReader();



                reader.onload =
                    () => {


                        resolve(
                            reader.result
                        );


                    };



                reader.onerror =
                    () => {


                        reject(
                            reader.error
                        );


                    };



                reader.readAsArrayBuffer(
                    file
                );


            }
        );


    }



async loadPDF(arrayBuffer){


    console.log(
        'Loading PDF'
    );


    console.log(
        'Worker:',
        pdfjsLib.GlobalWorkerOptions.workerSrc
    );


    const loadingTask =
        pdfjsLib.getDocument({

            data: arrayBuffer

        });



    this.pdfDocument =
        await loadingTask.promise;



    this.totalPages =
        this.pdfDocument.numPages;



    console.log(
        'Total Pages:',
        this.totalPages
    );


    await this.extractPages();

}
    async extractPages(){


        this.pdfData = [];


        let pageNumber = 1;



        while(
            pageNumber <= this.totalPages
        ){



            const endPage =
                Math.min(
                    pageNumber + CHUNK_SIZE - 1,
                    this.totalPages
                );



            console.log(
                `Processing ${pageNumber}-${endPage}`
            );



            for(
                let i = pageNumber;
                i <= endPage;
                i++
            ){



                await this.extractPageText(
                    i
                );



                this.progress =
                    Math.round(
                        (i / this.totalPages) * 100
                    );


            }



            await this.sleep(
                50
            );



            pageNumber =
                endPage + 1;


        }



        this.totalRecords =
            this.pdfData.length;



        this.currentPage = 1;


        this.preparePagination();



        console.log(
            'PDF Extraction Completed',
            this.totalRecords
        );



    }
    async extractPageText(pageNumber){


        try{


            const page =
                await this.pdfDocument.getPage(
                    pageNumber
                );



            const textContent =
                await page.getTextContent();



            let pageText =
                textContent.items
                .map(item => item.str)
                .join(' ');



            pageText =
                this.cleanText(
                    pageText
                );



            this.pdfData.push({

                id:
                    'page_' + pageNumber,

                pageNumber:
                    pageNumber,

                text:
                    pageText,

                characters:
                    pageText.length

            });



            page.cleanup();



        }
        catch(error){


            console.error(
                `Page ${pageNumber} Error`,
                error
            );



            this.pdfData.push({

                id:
                    'page_' + pageNumber,

                pageNumber:
                    pageNumber,

                text:
                    'Unable to extract text',

                characters:
                    0

            });


        }


    }




    cleanText(text){


        if(!text){
            return '';
        }



        return text
            .replace(/\s+/g,' ')
            .trim();



    }




    preparePagination(){


        const start =
            (this.currentPage - 1)
            * PAGE_SIZE;



        const end =
            start + PAGE_SIZE;



        this.displayedData =
            this.pdfData.slice(
                start,
                end
            );



    }




    handleNext(){


        if(
            this.currentPage <
            this.totalPagesCount
        ){


            this.currentPage++;


            this.preparePagination();


        }


    }




    handlePrevious(){


        if(
            this.currentPage > 1
        ){


            this.currentPage--;


            this.preparePagination();


        }


    }




    get totalPagesCount(){


        return Math.ceil(
            this.totalRecords / PAGE_SIZE
        );


    }




    get disablePrevious(){


        return this.currentPage === 1;


    }





    get disableNext(){


        return (
            this.currentPage ===
            this.totalPagesCount
        );


    }





    get progressLabel(){


        return `${this.progress}% Completed`;


    }





    sleep(milliseconds){


        return new Promise(
            resolve =>
                setTimeout(
                    resolve,
                    milliseconds
                )
        );


    }





    resetData(){


        this.pdfData = [];

        this.displayedData = [];

        this.progress = 0;

        this.currentPage = 1;

        this.totalRecords = 0;

        this.pdfDocument = null;


    }





    showError(message){


        const event =
            new ShowToastEvent({

                title:
                    'Error',

                message:
                    message,

                variant:
                    'error'

            });



        this.dispatchEvent(
            event
        );


    }





    disconnectedCallback(){


        try{


            if(
                this.pdfDocument
            ){


                this.pdfDocument.destroy();


                this.pdfDocument = null;


            }


        }
        catch(error){


            console.error(
                'Cleanup Error',
                error
            );


        }


    }




}