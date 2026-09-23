public class CsvImportWrapper {


    @AuraEnabled
    public String objectName;


    @AuraEnabled
    public Integer totalRecords;


    @AuraEnabled
    public Integer successCount;


    @AuraEnabled
    public Integer failedCount;


    @AuraEnabled
    public List<String> errors;


    @AuraEnabled
    public List<String> successMessages;


}