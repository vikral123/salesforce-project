import { LightningElement } from 'lwc';

export default class CsvUploader extends LightningElement {

    csvRecords = [];
    fileName = '';
    selectedFile;

    get disableSubmit() {
        return !this.selectedFile || this.csvRecords.length === 0;
    }

    handleFileChange(event) {

        const file = event.target.files[0];

        if (file) {

            this.selectedFile = file;
            this.fileName = file.name;

            const reader = new FileReader();

            reader.onload = () => {

                const csvText = reader.result;

                console.log('CSV TEXT:', csvText);

                this.csvRecords = this.parseCSV(csvText); //csv ko json arrya bana hai

                console.log('Parsed CSV Records:', this.csvRecords);
                console.log('Record Count:', this.csvRecords.length);
            };

            reader.onerror = () => {
                console.error('Error reading file:', reader.error);
                this.csvRecords = [];
            };

            reader.readAsText(file);

        }
    }

    parseCSV(csvText) {

        let rows = csvText.split(/\r?\n/);

        if (rows.length === 0) {
            return [];
        }

        let headers = rows[0]
            .replace(/\r/g, '')
            .split(',')
            .map(header => header.trim().replace(/"/g, ''));

        console.log('CSV Headers:', headers);

        let data = [];

        for (let i = 1; i < rows.length; i++) {

            if (!rows[i].trim()) {
                continue;
            } //csv empty line skip

            let values = rows[i]
                .split(',')
                .map(value => value.trim().replace(/"/g, ''));

            let record = {};

            headers.forEach((header, index) => {
                record[header] = values[index] || '';
            });

            // Synthetic unique key so lightning-datatable always has a valid key-field,
            // regardless of what columns the uploaded CSV actually contains.
            record._rowId = 'row_' + i;

            data.push(record);
        }

        return data;
    }

    handleSubmit() {

        if (this.csvRecords.length === 0) {
            console.log('CSV data is empty');
            return;
        }

        console.log('Sending CSV Data:', this.csvRecords);

        this.dispatchEvent(
            new CustomEvent('csvdata', {
                detail: this.csvRecords
            })   //child LWC component se parent LWC component ko data bhejne ka kaam karta hai.
        );
    }
}
