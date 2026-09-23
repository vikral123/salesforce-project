public with sharing class CurrentUserController {

    @AuraEnabled(cacheable=true)
    public static Integer getHighPriorityCaseCount(Id userId) {
        return [
            SELECT COUNT()
            FROM Case
            WHERE OwnerId = :userId
            AND Priority = 'High'
        ];
    }
}