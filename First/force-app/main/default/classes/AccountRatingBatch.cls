public class AccountRatingBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, Name, Rating FROM Account'
        ); 
    }

    public void execute(
        Database.BatchableContext bc, 
        List<Account> accounts
    ) {
        Map<Id, Integer> contactCountMap = new Map<Id, Integer>();
        List<AggregateResult> results = [
            SELECT AccountId, COUNT(Id) contactCount
            FROM Contact
            WHERE AccountId IN :accounts
            GROUP BY AccountId
        ];

    
        for (AggregateResult ar : results) {

            Id accountId = (Id) ar.get('AccountId');

            Integer contactCount = (Integer) ar.get('contactCount');

            contactCountMap.put(accountId, contactCount);
        }

      
        for (Account acc : accounts) {

            Integer count = contactCountMap.containsKey(acc.Id)
                ? contactCountMap.get(acc.Id)
                : 0;

            if (count >= 5) {

                acc.Rating = 'Hot';

            } else if (count >= 2) {

                acc.Rating = 'Warm';

            } else {

                acc.Rating = 'Cold';
            }
        }

     
        if (!accounts.isEmpty()) {
            update accounts;
        }
    }

    // FINISH
    public void finish(Database.BatchableContext bc) {

        System.debug('Account Rating Batch Completed');
    }
}