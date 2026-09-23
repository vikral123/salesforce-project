public with sharing class AccountHistoryController {

    @AuraEnabled(cacheable=true)
    public static List<AccountHistory> getLatestHistory() {
        return [
            SELECT Id, AccountId, Account.Name, Field, OldValue, NewValue,
                   CreatedDate, CreatedBy.Name
            FROM AccountHistory
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<AccountHistory> getAllHistory() {
        return [
            SELECT Id, AccountId, Account.Name, Field, OldValue, NewValue,
                   CreatedDate, CreatedBy.Name
            FROM AccountHistory
            ORDER BY CreatedDate DESC
        ];
    }
}