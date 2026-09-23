public class CsvImportService {


    public static CsvImportWrapper importCSV(String recordsJson) {


        CsvImportWrapper response =
            new CsvImportWrapper();


        response.successCount = 0;
        response.failedCount = 0;

        response.errors =
            new List<String>();

        response.successMessages =
            new List<String>();


        try {


            List<Object> records =
                (List<Object>) JSON.deserializeUntyped(recordsJson);



            response.totalRecords =
                records.size();



            String objectName =
                CsvObjectDetector.detectObject(records);



            response.objectName =
                objectName;



            List<SObject> recordsToInsert =
                DynamicFieldMapper.mapRecords(
                    objectName,
                    records   //CSV data ko Salesforce Records me convert karta hai
                );



            List<SObject> validRecords =
                new List<SObject>();


            List<Account> accountsToInsert =
                new List<Account>();


            List<Account> accountsToUpdate =
                new List<Account>();



            /*
             * ACCOUNT LOGIC
             */

            if(objectName == 'Account') {



                Set<String> phoneNumbers =
                    new Set<String>();



                for(SObject obj : recordsToInsert) {


                    Account acc =
                        (Account)obj;



                    if(String.isNotBlank(acc.Phone)) {


                        phoneNumbers.add(
                            acc.Phone
                        );

                    }

                }





                Map<String,Account> existingAccounts =
                    new Map<String,Account>();



                if(!phoneNumbers.isEmpty()) {



                    for(Account acc :
                        [
                            SELECT Id,Name,Phone
                            FROM Account
                            WHERE Phone IN :phoneNumbers
                        ]
                    ) {
                        existingAccounts.put(
                            acc.Phone,
                            acc
                        );
                    }

                }
                
                Set<String> csvPhoneDuplicate =
                    new Set<String>();

Set<String> processedPhones =
    new Set<String>();

                Integer rowNumber = 0;



                for(SObject obj : recordsToInsert) {



                    rowNumber++;



                    Account acc =
                        (Account)obj;



                    /*
                     * Phone Mandatory
                     */

                    if(String.isBlank(acc.Phone)) {



                        response.failedCount++;


                        response.errors.add(
                            'Row '
                            + rowNumber
                            + ': Phone is required'
                        );


                        continue;

                    }





                    /*
                     * Existing Account
                     * Update only Name
                     */
if(existingAccounts.containsKey(acc.Phone)) {


    if(processedPhones.contains(acc.Phone)) {


        response.failedCount++;


        response.errors.add(
            'Row '
            + rowNumber
            + ': Duplicate phone in CSV '
            + acc.Phone
        );


        continue;

    }



    Account existingAcc =
        existingAccounts.get(acc.Phone);



    Map<String,Object> fields =
        acc.getPopulatedFieldsAsMap();



    for(String fieldName : fields.keySet()) {


        if(fieldName != 'Id'
            && fieldName != 'Phone') {


            existingAcc.put(
                fieldName,
                fields.get(fieldName)
            );

        }

    }



    accountsToUpdate.add(existingAcc);



    processedPhones.add(acc.Phone);



    continue;

}





                    /*
                     * CSV Duplicate
                     */

                    if(csvPhoneDuplicate.contains(acc.Phone)) {



                        response.failedCount++;


                        response.errors.add(
                            'Row '
                            + rowNumber
                            + ': Duplicate phone found in CSV '
                            + acc.Phone
                        );


                        continue;

                    }



                    csvPhoneDuplicate.add(
                        acc.Phone
                    );



                    accountsToInsert.add(
                        acc
                    );


                }


            }
            else {


                /*
                 * Other Objects
                 */

                validRecords.addAll(
                    recordsToInsert
                );


            }





            /*
             * INSERT NEW ACCOUNT
             */

            if(!accountsToInsert.isEmpty()) {


Database.SaveResult[] insertResults =
    Database.insert(
        accountsToInsert,
        false
    );


for(Integer i = 0; i < insertResults.size(); i++) {

    Database.SaveResult sr = insertResults[i];

    Account acc = accountsToInsert[i];


    if(sr.isSuccess()) {

        response.successCount++;

        response.successMessages.add(
            'New Account Created Successfully: '
            + 'Name = '
            + acc.Name
            + ', Phone = '
            + acc.Phone
        );

    }
    else {

        response.failedCount++;

        for(Database.Error err : sr.getErrors()) {

            response.errors.add(
                'Insert Error: '
                + err.getMessage()
            );

        }

    }

}

            }







            /*
             * UPDATE EXISTING ACCOUNT
             */

            if(!accountsToUpdate.isEmpty()) {



                Database.SaveResult[] updateResults =
                    Database.update(
                        accountsToUpdate,
                        false
                    );



                for(Integer i=0;
                    i < updateResults.size();
                    i++
                ) {



                    Database.SaveResult sr =
                        updateResults[i];



                    Account acc =
                        accountsToUpdate[i];



                    if(sr.isSuccess()) {



                        response.successCount++;



                     response.successMessages.add(
    'Existing Account Updated Successfully: '
    + 'Name = '
    + acc.Name
    + ', Phone = '
    + acc.Phone
);



                    }
                    else {



                        response.failedCount++;



                        for(Database.Error err :
                            sr.getErrors()
                        ) {



                            response.errors.add(
                                'Update Error: '
                                + err.getMessage()
                            );

                        }


                    }


                }


            }







            /*
             * INSERT OTHER OBJECTS
             */

            if(!validRecords.isEmpty()) {



                Database.SaveResult[] results =
                    Database.insert(
                        validRecords,
                        false
                    );



                processResults(
                    results,
                    response
                );


            }



        }
        catch(Exception e) {



            response.failedCount++;



            response.errors.add(
                'Apex Exception: '
                + e.getTypeName()
                + ' - '
                + e.getMessage()
            );



            System.debug(
                e.getMessage()
            );


        }



        return response;


    }







    /*
     * Common DML Handler
     */

    private static void processResults(
        Database.SaveResult[] results,
        CsvImportWrapper response
    ) {



        for(Database.SaveResult sr :
            results
        ) {



            if(sr.isSuccess()) {


                response.successCount++;


            }
            else {


                response.failedCount++;



                for(Database.Error err :
                    sr.getErrors()
                ) {



                    response.errors.add(
                        'DML Error: '
                        + err.getStatusCode()
                        + ' - '
                        + err.getMessage()
                    );

                }


            }


        }


    }

}