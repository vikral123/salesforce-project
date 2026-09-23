public class AccountTriggerHandler {
    public static Boolean isSyncing = false;
    public static void updateAccountRating(List<Account> accountList) {
        for (Account acc : accountList) {
            if (acc.Industry == 'Banking' || acc.Industry == 'Healthcare') {
                acc.Rating = 'Hot';
            } else {
                acc.Rating = 'Warm';
            }
        }
    }
    public static void syncContactPhoneFax(List<Account> newList, Map<Id, Account> oldMap) {
        if (isSyncing || ContactPhoneFaxSyncHandler.isSyncing) return;
        Set<Id> changedAccountIds = new Set<Id>();
        Map<Id, Account> changedAccountMap = new Map<Id, Account>();
        for (Account acc : newList) {
            Account oldAcc = oldMap.get(acc.Id);
            if (acc.Phone != oldAcc.Phone || acc.Fax != oldAcc.Fax) {
                changedAccountIds.add(acc.Id);
                changedAccountMap.put(acc.Id, acc);
            }
        }
        if (changedAccountIds.isEmpty()) return;
        List<Contact> contactsToUpdate = new List<Contact>();
        for (Contact con : [
            SELECT Id, Phone, Fax, AccountId
            FROM Contact
            WHERE AccountId IN :changedAccountIds
        ]) {
            Account acc = changedAccountMap.get(con.AccountId);
            con.Phone = acc.Phone;
            con.Fax   = acc.Fax;
            contactsToUpdate.add(con);
        }
        if (!contactsToUpdate.isEmpty()) {
            isSyncing = true;
            try {
                Database.SaveResult[] results = Database.update(contactsToUpdate, false);
                for (Integer i = 0; i < results.size(); i++) {
                    if (!results[i].isSuccess()) {
                        for (Database.Error err : results[i].getErrors()) {
                            System.debug('Sync failed for Contact '
                                + contactsToUpdate[i].Id + ': ' + err.getMessage());
                        }
                    }
                }
            } finally {
                isSyncing = false;
            }
        }
    }
}