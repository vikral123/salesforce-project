public with sharing class DynamicFieldMapper {

    public static List<SObject> mapRecords(
        String objectName,
        List<Object> records
    ) {

        List<SObject> sObjects = new List<SObject>();

        Schema.SObjectType objType =
            Schema.getGlobalDescribe().get(objectName);

        Map<String, Schema.SObjectField> fieldMap =
            objType.getDescribe().fields.getMap();

        for (Object row : records) {

            Map<String, Object> csvRow =
                (Map<String, Object>) row;

            SObject obj = objType.newSObject();

            for (String header : csvRow.keySet()) {

                if (!fieldMap.containsKey(header)) {
                    continue;
                }

                Schema.DescribeFieldResult fieldDescribe =
                    fieldMap.get(header).getDescribe();

                Object rawValue = csvRow.get(header);

                if (rawValue == null) {
                    continue;
                }

                String value = String.valueOf(rawValue).trim();

                if (String.isBlank(value)) {
                    continue;
                }

                Schema.DisplayType fieldType =
                    fieldDescribe.getType();

                try {

                    if (fieldType == Schema.DisplayType.Integer) {

                        obj.put(
                            header,
                            Integer.valueOf(value)
                        );

                    }
                    else if (
                        fieldType == Schema.DisplayType.Currency ||
                        fieldType == Schema.DisplayType.Double ||
                        fieldType == Schema.DisplayType.Percent
                    ) {

                        obj.put(
                            header,
                            Decimal.valueOf(value)
                        );

                    }
                    else if (fieldType == Schema.DisplayType.Boolean) {

                        obj.put(
                            header,
                            Boolean.valueOf(value)
                        );

                    }
                    else if (fieldType == Schema.DisplayType.Date) {

                        obj.put(
                            header,
                            Date.valueOf(value)
                        );

                    }
                    else if (fieldType == Schema.DisplayType.DateTime) {

                        obj.put(
                            header,
                            Datetime.valueOf(value)
                        );

                    }
                    else {

                        obj.put(
                            header,
                            value
                        );

                    }

                }
                catch (Exception e) {

                    throw new AuraHandledException(
                        'Invalid value "' +
                        value +
                        '" for field "' +
                        header +
                        '" (' +
                        fieldType +
                        ').'
                    );

                }

            }

            sObjects.add(obj);

        }

        return sObjects;

    }

}