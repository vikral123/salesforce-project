/**
 * ExcelUploadController
 * - saveRecords: excel se aaya JSON data ko bulk insert karta hai (chunks mein call hoga)
 * - getRecords : dusre LWC component ke liye records fetch karta hai
 *
 * NOTE: "Contact_Import__c" custom object banao (Setup > Object Manager > Create)
 * ya apna existing object use karo. Fields yaha example ke liye hain:
 *   Name (standard text field, already exists on all custom objects)
 *   Email__c (Text)
 *   Phone__c (Text)
 * Apna actual excel column structure dekh kar fields/mapping change kar lena.
 */
public with sharing class ExcelUploadController {

    @AuraEnabled
    public static String saveRecords(String jsonData) {
        try {
            List<Object> rows = (List<Object>) JSON.deserializeUntyped(jsonData);
            List<Contact_Import__c> recordsToInsert = new List<Contact_Import__c>();

            for (Object rowObj : rows) {
                Map<String, Object> row = (Map<String, Object>) rowObj;
                Contact_Import__c rec = new Contact_Import__c();

                // ---- Apne excel ke column headers ke hisaab se mapping change karo ----
                if (row.containsKey('Name')) {
                    rec.Name = String.valueOf(row.get('Name'));
                }
                if (row.containsKey('Email')) {
                    rec.Email__c = String.valueOf(row.get('Email'));
                }
                if (row.containsKey('Phone')) {
                    rec.Phone__c = String.valueOf(row.get('Phone'));
                }
                // ------------------------------------------------------------------

                recordsToInsert.add(rec);
            }

            if (!recordsToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(recordsToInsert, false);
                Integer successCount = 0;
                for (Database.SaveResult sr : results) {
                    if (sr.isSuccess()) {
                        successCount++;
                    }
                }
                return successCount + ' of ' + recordsToInsert.size() + ' records saved';
            }
            return '0 records saved';
        } catch (Exception e) {
            throw new AuraHandledException('Error saving records: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact_Import__c> getRecords() {
        return [
            SELECT Id, Name, Email__c, Phone__c
            FROM Contact_Import__c
            ORDER BY CreatedDate DESC
            LIMIT 2000
        ];
    }
}
