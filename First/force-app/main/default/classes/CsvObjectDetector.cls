public with sharing class CsvObjectDetector {

    public static String detectObject(List<Object> records) {

        if (records == null || records.isEmpty()) {
            return null;
        }

        // First row of CSV
        Map<String, Object> firstRow =
            (Map<String, Object>) records[0];

        // CSV Headers
        Set<String> csvHeaders = firstRow.keySet();

        // Objects we want to support
        List<String> supportedObjects = new List<String>{
            'Account',
            'Lead',
            'Opportunity'
        };

        String detectedObject;
        Integer maxMatches = 0;

        for (String objectName : supportedObjects) {

            Schema.SObjectType objType =
                Schema.getGlobalDescribe().get(objectName);

            Map<String, Schema.SObjectField> fieldMap =
                objType.getDescribe().fields.getMap();

            Integer matchCount = 0;

            for (String header : csvHeaders) {

                if (fieldMap.containsKey(header)) {
                    matchCount++;
                }

            }

            if (matchCount > maxMatches) {
                maxMatches = matchCount;
                detectedObject = objectName;
            }

        }

        return detectedObject;

    }

}