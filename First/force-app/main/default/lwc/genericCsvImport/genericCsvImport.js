import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import importCSV from '@salesforce/apex/GenericCsvImportController.importCSV';
export default class GenericCsvImport extends LightningElement {

    selectedFile;
    fileName = '';

    @track Recordscsv = [];

    isLoading = false;

    get disableSubmit() {
        return !this.selectedFile;
    }

    get formattedRecords() {
        return JSON.stringify(this.csvRecords, null, 2);
        //convert javscript object into redable string format
    }

    handleFileChange(event) {

        if (event.target.files.length > 0) {
            this.selectedFile = event.target.files[0];
            this.fileName = this.selectedFile.name;
        }
    }
   async handleSubmit() {

    if (!this.selectedFile) {
        alert('Please select a CSV file.');
        return;
    }

    this.isLoading = true;

    const reader = new FileReader(); //FileReader browser ka built-in JavaScript API hai.
//Iska kaam hai user ke selected file ko read karna.
    reader.onload = async () => {

        const csv = reader.result;
this.csvRecords = this.parseCSV(csv); //Convert CSV into Salesforce Format

console.log('CSV Records Length:', this.csvRecords.length);
console.log('CSV Records Data:', JSON.stringify(this.csvRecords));
        console.log('CSV Records');
        console.log(this.csvRecords);

        try {

            const result = await importCSV({
                recordsJson: JSON.stringify(this.csvRecords)
            });
if (result.failedCount > 0) {

    this.dispatchEvent(
        new ShowToastEvent({
            title: 'Import Failed',
            message: result.errors.join(', '),
            variant: 'error'
        })
    );

} 


if (result.successMessages && result.successMessages.length > 0) {

    this.dispatchEvent(
        new ShowToastEvent({
            title: 'Import Result',
            message: result.successMessages.join(', '),
            variant: 'success'
        })
    );

}
            console.log('Apex Response');
            console.log(result);

        } catch (error) {

            console.error('Error:', error);

        } finally {

            this.isLoading = false;

        }

    };

    reader.readAsText(this.selectedFile); //uesr ke selected file ko text format me read karna.
}

    parseCSV(csv) {

        const lines = csv.trim().split('\n');

        const headers = lines[0]
            .split(',')
            .map(item => item.trim());  // trim remove extra spaces

        const records = [];

        for (let i = 1; i < lines.length; i++) {

            const values = lines[i].split(',');

            let obj = {};

          headers.forEach((header, index) => {
    const cleanHeader = header.replace(/"/g, '').trim();
    const cleanValue = values[index]
        ? values[index].replace(/"/g, '').trim()
        : '';

    obj[cleanHeader] = cleanValue;
});

            records.push(obj);

        }

        return records;
    }
    

}