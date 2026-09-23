import { LightningElement, api } from 'lwc';

export default class ExcelDisplay extends LightningElement {

    @api excelData = [];

    get columns() {

        if (!this.excelData || this.excelData.length === 0) {
            return [];
        }

        return Object.keys(this.excelData[0]).map(key => ({
            label: key,
            fieldName: key
        }));
    }
}