import { LightningElement, api } from 'lwc';

export default class CsvViewer extends LightningElement {

    data = [];
    columns = [];

    @api
    set csvData(value) {

        this.data = value || [];

        if (this.data.length > 0) {

            this.columns = Object.keys(this.data[0])
                .filter(field => field !== '_rowId') // hide the internal row key from the table
                .map(field => {
                    return {
                        label: field,
                        fieldName: field
                    };
                });
        } else {
            this.columns = [];
        }
    }

    get csvData() {
        return this.data;
    }

    get hasData() {
        return this.data && this.data.length > 0;
    }
}