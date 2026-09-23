public class AccountApiBatch 
    implements Database.Batchable<SObject>, Database.AllowsCallouts {

    // START
    public Database.QueryLocator start(Database.BatchableContext bc) {

        return Database.getQueryLocator(
            'SELECT Id, Name, Description FROM Account LIMIT 500'
        );
    }

    // EXECUTE
    public void execute(
        Database.BatchableContext bc,
        List<Account> accounts
    ) {

        List<Account> accountsToUpdate = new List<Account>();

        for (Account acc : accounts) {

            try {

                // Create HTTP request
                HttpRequest req = new HttpRequest();

                req.setEndpoint(
                    'https://api.example.com/account/' + acc.Id
                );

                req.setMethod('GET');
                req.setTimeout(10000);

                // Send request
                Http http = new Http();

                HttpResponse res = http.send(req);

                // Check response
                if (res.getStatusCode() == 200) {

                    // Parse response
                    Map<String, Object> responseData =
                        (Map<String, Object>) JSON.deserializeUntyped(
                            res.getBody()
                        );

                    String status =
                        (String) responseData.get('status');

                    // Update Account based on API response
                    acc.Description = 'API Status: ' + status;

                    accountsToUpdate.add(acc);
                }
                else {

                    System.debug(
                        'API failed for Account: ' +
                        acc.Id +
                        ' Status: ' +
                        res.getStatusCode()
                    );
                }

            }
            catch (Exception e) {

                // Handle failed callout
                System.debug(
                    'Callout failed for Account ' +
                    acc.Id +
                    ': ' +
                    e.getMessage()
                );
            }
        }

        // ONE bulk update
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }

    // FINISH
    public void finish(Database.BatchableContext bc) {

        System.debug('Account API Batch completed.');
    }
}