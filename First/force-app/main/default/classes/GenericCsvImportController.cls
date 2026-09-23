public with sharing class GenericCsvImportController {

    @AuraEnabled
    public static CsvImportWrapper importCSV(String recordsJson) {
 System.debug('Received JSON: ' + recordsJson);
        return CsvImportService.importCSV(recordsJson);

    }

}

//Yeh Salesforce Apex ka Controller hai. Iska main kaam hai LWC se CSV ka data lena aur Service class ko bhejna.