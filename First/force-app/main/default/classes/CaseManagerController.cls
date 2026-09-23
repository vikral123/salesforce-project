public with sharing class CaseManagerController {

    // =========================================================
    // Wrapper for paginated Case response
    // =========================================================

    public class CaseResult {

        @AuraEnabled
        public List<Case> records;

        @AuraEnabled
        public Integer totalRecords;

        @AuraEnabled
        public Integer totalPages;

        @AuraEnabled
        public Integer pageNumber;

        @AuraEnabled
        public Integer pageSize;
    }


    // =========================================================
    // Get Cases
    // Search + Filter + Pagination
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static CaseResult getCases(
        Id accountId,
        String searchKey,
        String status,
        String priority,
        Integer pageNumber,
        Integer pageSize
    )
    {

        CaseResult result = new CaseResult();

        result.records = new List<Case>();
        result.totalRecords = 0;
        result.totalPages = 0;
        result.pageNumber = 1;
        result.pageSize = 10;

        // -----------------------------------------------------
        // Validate Account
        // -----------------------------------------------------

        if (accountId == null) {
            return result;
        }


        // -----------------------------------------------------
        // Default Page Values
        // -----------------------------------------------------

        if (pageNumber == null || pageNumber < 1) {
            pageNumber = 1;
        }

        if (pageSize == null || pageSize < 1) {
            pageSize = 10;
        }

        // Prevent unnecessarily large queries
        if (pageSize > 100) {
            pageSize = 100;
        }


        result.pageNumber = pageNumber;
        result.pageSize = pageSize;


        // -----------------------------------------------------
        // Search Variables
        // -----------------------------------------------------

        String searchValue;

        if (!String.isBlank(searchKey)) {
            searchValue = '%' + searchKey.trim() + '%';
        }


        // -----------------------------------------------------
        // COUNT Query
        // -----------------------------------------------------

        Integer totalRecords;

        if (
            !String.isBlank(searchKey) &&
            !String.isBlank(status) &&
            status != 'All' &&
            !String.isBlank(priority) &&
            priority != 'All'
        ) 
        {
            totalRecords = [
                SELECT COUNT()
                FROM Case
                WHERE AccountId = :accountId
                AND (
                    Subject LIKE :searchValue
                    OR CaseNumber LIKE :searchValue
                )
                AND Status = :status
                AND Priority = :priority
            ];
        }
        else if
         (
            !String.isBlank(searchKey) &&
            !String.isBlank(status) &&
            status != 'All' ) 
        {
            totalRecords = [
                SELECT COUNT()
                FROM Case
                WHERE AccountId = :accountId
                AND (
                    Subject LIKE :searchValue
                    OR CaseNumber LIKE :searchValue
                )
                AND Status = :status
            ];
        }
        else if (
            !String.isBlank(searchKey) &&
            !String.isBlank(priority) &&
            priority != 'All'
        ) {

            totalRecords = [
                SELECT COUNT()
                FROM Case
                WHERE AccountId = :accountId
                AND (
                    Subject LIKE :searchValue
                    OR CaseNumber LIKE :searchValue
                )
                AND Priority = :priority
            ];

        }
        else if (
            !String.isBlank(status) &&
            status != 'All' &&
            !String.isBlank(priority) &&
            priority != 'All'
        ) {

            totalRecords = [
                SELECT COUNT()
                FROM Case
                WHERE AccountId = :accountId
                AND Status = :status
                AND Priority = :priority
            ];

        }
        else if (
            !String.isBlank(searchKey)
        ) {

            totalRecords = [
                SELECT COUNT()
                FROM Case
                WHERE AccountId = :accountId
                AND (
                    Subject LIKE :searchValue
                    OR CaseNumber LIKE :searchValue
                )
            ];

        }
        else if (
            !String.isBlank(status) &&
            status != 'All'
        ) {

            totalRecords = [
                SELECT COUNT()
                FROM Case
                WHERE AccountId = :accountId
                AND Status = :status
            ];

        }
        else if (
            !String.isBlank(priority) &&
            priority != 'All'
        ) {

            totalRecords = [
                SELECT COUNT()
                FROM Case
                WHERE AccountId = :accountId
                AND Priority = :priority
            ];

        }
        else {

            totalRecords = [
                SELECT COUNT()
                FROM Case
                WHERE AccountId = :accountId
            ];
        }


        result.totalRecords = totalRecords;


        // -----------------------------------------------------
        // Calculate Total Pages
        // -----------------------------------------------------

        if (totalRecords == 0) {

            result.totalPages = 0;
            result.records = new List<Case>();

            return result;
        }


        result.totalPages =
            (Integer)Math.ceil(
                Decimal.valueOf(totalRecords) /
                Decimal.valueOf(pageSize)
            );


        // -----------------------------------------------------
        // Prevent invalid page
        // -----------------------------------------------------

        if (pageNumber > result.totalPages) {

            pageNumber = result.totalPages;

            result.pageNumber = pageNumber;
        }


        // -----------------------------------------------------
        // Offset
        // -----------------------------------------------------

        Integer offsetValue =
            (pageNumber - 1) * pageSize;


        // -----------------------------------------------------
        // Query Cases
        // -----------------------------------------------------

        if (
            !String.isBlank(searchKey) &&
            !String.isBlank(status) &&
            status != 'All' &&
            !String.isBlank(priority) &&
            priority != 'All'
        ) {

            result.records = [
                SELECT
                    Id,
                    CaseNumber,
                    Subject,
                    Status,
                    Priority,
                    Origin,
                    Type,
                    Reason,
                    Description,
                    ContactId,
                    Contact.Name,
                    AccountId,
                    Account.Name,
                    OwnerId,
                    Owner.Name,
                    CreatedDate,
                    LastModifiedDate
                FROM Case
                WHERE AccountId = :accountId
                AND (
                    Subject LIKE :searchValue
                    OR CaseNumber LIKE :searchValue
                )
                AND Status = :status
                AND Priority = :priority
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :offsetValue
            ];

        }
        else if (
            !String.isBlank(searchKey) &&
            !String.isBlank(status) &&
            status != 'All'
        ) {

            result.records = [
                SELECT
                    Id,
                    CaseNumber,
                    Subject,
                    Status,
                    Priority,
                    Origin,
                    Type,
                    Reason,
                    Description,
                    ContactId,
                    Contact.Name,
                    AccountId,
                    Account.Name,
                    OwnerId,
                    Owner.Name,
                    CreatedDate,
                    LastModifiedDate
                FROM Case
                WHERE AccountId = :accountId
                AND (
                    Subject LIKE :searchValue
                    OR CaseNumber LIKE :searchValue
                )
                AND Status = :status
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :offsetValue
            ];

        }
        else if (
            !String.isBlank(searchKey) &&
            !String.isBlank(priority) &&
            priority != 'All'
        ) {

            result.records = [
                SELECT
                    Id,
                    CaseNumber,
                    Subject,
                    Status,
                    Priority,
                    Origin,
                    Type,
                    Reason,
                    Description,
                    ContactId,
                    Contact.Name,
                    AccountId,
                    Account.Name,
                    OwnerId,
                    Owner.Name,
                    CreatedDate,
                    LastModifiedDate
                FROM Case
                WHERE AccountId = :accountId
                AND (
                    Subject LIKE :searchValue
                    OR CaseNumber LIKE :searchValue
                )
                AND Priority = :priority
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :offsetValue
            ];

        }
        else if (
            !String.isBlank(status) &&
            status != 'All' &&
            !String.isBlank(priority) &&
            priority != 'All'
        ) {

            result.records = [
                SELECT
                    Id,
                    CaseNumber,
                    Subject,
                    Status,
                    Priority,
                    Origin,
                    Type,
                    Reason,
                    Description,
                    ContactId,
                    Contact.Name,
                    AccountId,
                    Account.Name,
                    OwnerId,
                    Owner.Name,
                    CreatedDate,
                    LastModifiedDate
                FROM Case
                WHERE AccountId = :accountId
                AND Status = :status
                AND Priority = :priority
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :offsetValue
            ];

        }
        else if (
            !String.isBlank(searchKey)
        ) {

            result.records = [
                SELECT
                    Id,
                    CaseNumber,
                    Subject,
                    Status,
                    Priority,
                    Origin,
                    Type,
                    Reason,
                    Description,
                    ContactId,
                    Contact.Name,
                    AccountId,
                    Account.Name,
                    OwnerId,
                    Owner.Name,
                    CreatedDate,
                    LastModifiedDate
                FROM Case
                WHERE AccountId = :accountId
                AND (
                    Subject LIKE :searchValue
                    OR CaseNumber LIKE :searchValue
                )
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :offsetValue
            ];

        }
        else if (
            !String.isBlank(status) &&
            status != 'All'
        ) {

            result.records = [
                SELECT
                    Id,
                    CaseNumber,
                    Subject,
                    Status,
                    Priority,
                    Origin,
                    Type,
                    Reason,
                    Description,
                    ContactId,
                    Contact.Name,
                    AccountId,
                    Account.Name,
                    OwnerId,
                    Owner.Name,
                    CreatedDate,
                    LastModifiedDate
                FROM Case
                WHERE AccountId = :accountId
                AND Status = :status
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :offsetValue
            ];

        }
        else if (
            !String.isBlank(priority) &&
            priority != 'All'
        ) {

            result.records = [
                SELECT
                    Id,
                    CaseNumber,
                    Subject,
                    Status,
                    Priority,
                    Origin,
                    Type,
                    Reason,
                    Description,
                    ContactId,
                    Contact.Name,
                    AccountId,
                    Account.Name,
                    OwnerId,
                    Owner.Name,
                    CreatedDate,
                    LastModifiedDate
                FROM Case
                WHERE AccountId = :accountId
                AND Priority = :priority
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :offsetValue
            ];

        }
        else {

            result.records = [
                SELECT
                    Id,
                    CaseNumber,
                    Subject,
                    Status,
                    Priority,
                    Origin,
                    Type,
                    Reason,
                    Description,
                    ContactId,
                    Contact.Name,
                    AccountId,
                    Account.Name,
                    OwnerId,
                    Owner.Name,
                    CreatedDate,
                    LastModifiedDate
                FROM Case
                WHERE AccountId = :accountId
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :offsetValue
            ];
        }


        return result;
    }


    // =========================================================
    // Create Case
    // =========================================================

   @AuraEnabled
public static Case createCase(
    Id accountId,
    String subject,
    String description,
    String priority,
    String origin
) 

{

    System.debug('========== CREATE CASE START ==========');
    System.debug('accountId = ' + accountId);
    System.debug('subject = ' + subject);
    System.debug('description = ' + description);
    System.debug('priority = ' + priority);
    System.debug('origin = ' + origin);

    // -----------------------------------------
    // Validation
    // -----------------------------------------

    if (accountId == null) {
        System.debug('ERROR: Account Id is null');

        throw new AuraHandledException(
            'Account Id is required.'
        );
    }

    if (String.isBlank(subject)) {
        System.debug('ERROR: Subject is blank');

        throw new AuraHandledException(
            'Case Subject is required.'
        );
    }

    // -----------------------------------------
    // Create Case
    // -----------------------------------------

    Case newCase = new Case();

    newCase.AccountId = accountId;
    newCase.Subject = subject;
    newCase.Description = description;

    if (!String.isBlank(priority)) {
        newCase.Priority = priority;
    }

    if (!String.isBlank(origin)) {
        newCase.Origin = origin;
    }

    System.debug('Case before insert = ' + newCase);

    try {

        System.debug('Going to INSERT Case...');

        insert newCase;

        System.debug('CASE INSERT SUCCESS');
        System.debug('Created Case Id = ' + newCase.Id);

        // -----------------------------------------
        // Query created Case
        // -----------------------------------------

        Case createdCase = [
            SELECT
                Id,
                CaseNumber,
                Subject,
                Status,
                Priority,
                Origin,
                Type,
                Reason,
                Description,
                ContactId,
                Contact.Name,
                AccountId,
                Account.Name,
                OwnerId,
                Owner.Name,
                CreatedDate,
                LastModifiedDate
            FROM Case
            WHERE Id = :newCase.Id
            LIMIT 1
        ];

        System.debug(
            'Created Case after query = ' + createdCase
        );

        System.debug(
            'Created Case Number = ' +
            createdCase.CaseNumber
        );

        System.debug('========== CREATE CASE END ==========');

        return createdCase;

    }
    catch (DmlException e) {

        System.debug('========== CREATE CASE DML ERROR ==========');

        System.debug('DML Message = ' + e.getMessage());
        System.debug('DML Type = ' + e.getTypeName());

        System.debug(
            'DML Status Code = ' +
            e.getDmlStatusCode(0)
        );

        System.debug(
            'DML Fields = ' +
            e.getDmlFields(0)
        );

        System.debug(
            'DML Error Message = ' +
            e.getDmlMessage(0)
        );

        throw new AuraHandledException(
            'Unable to create Case: ' +
            e.getDmlMessage(0)
        );

    }
    catch (Exception e) {

        System.debug('========== CREATE CASE GENERAL ERROR ==========');

        System.debug('Exception Type = ' + e.getTypeName());
        System.debug('Exception Message = ' + e.getMessage());
        System.debug('Stack Trace = ' + e.getStackTraceString());

        throw new AuraHandledException(
            'Unable to create Case: ' +
            e.getMessage()
        );
    }
}

    // =========================================================
    // Update Case Status
    // =========================================================

    @AuraEnabled
    public static Case updateCaseStatus(
        Id caseId,
        String status
    ) {

        if (caseId == null) {
            throw new AuraHandledException(
                'Case Id is required.'
            );
        }

        if (String.isBlank(status)) {
            throw new AuraHandledException(
                'Status is required.'
            );
        }


        try {

            Case caseRecord = [
                SELECT
                    Id,
                    CaseNumber,
                    Subject,
                    Status,
                    Priority,
                    Origin,
                    Type,
                    Reason,
                    Description,
                    ContactId,
                    Contact.Name,
                    AccountId,
                    Account.Name,
                    OwnerId,
                    Owner.Name,
                    CreatedDate,
                    LastModifiedDate
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];


            caseRecord.Status = status;

            update caseRecord;


            return [
                SELECT
                    Id,
                    CaseNumber,
                    Subject,
                    Status,
                    Priority,
                    Origin,
                    Type,
                    Reason,
                    Description,
                    ContactId,
                    Contact.Name,
                    AccountId,
                    Account.Name,
                    OwnerId,
                    Owner.Name,
                    CreatedDate,
                    LastModifiedDate
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

        }
        catch (DmlException e) {

            throw new AuraHandledException(
                'Unable to update Case: ' +
                e.getDmlMessage(0)
            );

        }
        catch (Exception e) {

            throw new AuraHandledException(
                'Unable to update Case: ' +
                e.getMessage()
            );
        }
    }


    // =========================================================
    // Update Full Case
    // =========================================================

    @AuraEnabled
    public static Case updateCase(
        Id caseId,
        String subject,
        String status,
        String priority,
        String origin,
        String type,
        String reason,
        String description,
        Id contactId
    ) {

        if (caseId == null) {
            throw new AuraHandledException(
                'Case Id is required.'
            );
        }


        try {

            Case existingCase = [
                SELECT
                    Id,
                    Subject,
                    Status,
                    Priority,
                    Origin,
                    Type,
                    Reason,
                    Description,
                    ContactId
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];


            if (subject != null) {
                existingCase.Subject = subject;
            }

            if (status != null) {
                existingCase.Status = status;
            }

            if (priority != null) {
                existingCase.Priority = priority;
            }

            if (origin != null) {
                existingCase.Origin = origin;
            }

            if (type != null) {
                existingCase.Type = type;
            }

            if (reason != null) {
                existingCase.Reason = reason;
            }

            if (description != null) {
                existingCase.Description = description;
            }

            if (contactId != null) {
                existingCase.ContactId = contactId;
            }


            update existingCase;


            return [
                SELECT
                    Id,
                    CaseNumber,
                    Subject,
                    Status,
                    Priority,
                    Origin,
                    Type,
                    Reason,
                    Description,
                    ContactId,
                    Contact.Name,
                    AccountId,
                    Account.Name,
                    OwnerId,
                    Owner.Name,
                    CreatedDate,
                    LastModifiedDate
                FROM Case
                WHERE Id = :existingCase.Id
                LIMIT 1
            ];

        }
        catch (DmlException e) {

            throw new AuraHandledException(
                'Unable to update Case: ' +
                e.getDmlMessage(0)
            );

        }
        catch (Exception e) {

            throw new AuraHandledException(
                'Unable to update Case: ' +
                e.getMessage()
            );
        }
    }


    // =========================================================
    // Delete Case
    // =========================================================

    @AuraEnabled
    public static void deleteCase(Id caseId) {

        if (caseId == null) {
            throw new AuraHandledException(
                'Case Id is required.'
            );
        }


        try {

            Case caseToDelete = [
                SELECT Id
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            delete caseToDelete;

        }
        catch (DmlException e) {

            throw new AuraHandledException(
                'Unable to delete Case: ' +
                e.getDmlMessage(0)
            );
        }
    }


    // =========================================================
    // Get Account Contacts
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static List<Contact> getAccountContacts(
        Id accountId
    ) {

        if (accountId == null) {
            return new List<Contact>();
        }


        return [
            SELECT
                Id,
                Name,
                Email,
                Phone
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY Name
        ];

    }


    // =========================================================
    // Get Case Picklist Values
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>>
    getCasePicklistValues() {

        Map<String, List<String>> result =
            new Map<String, List<String>>();

        result.put(
            'Status',
            getPicklistValues(Case.Status)
        );

        result.put(
            'Priority',
            getPicklistValues(Case.Priority)
        );

        result.put(
            'Origin',
            getPicklistValues(Case.Origin)
        );

        result.put(
            'Type',
            getPicklistValues(Case.Type)
        );

        result.put(
            'Reason',
            getPicklistValues(Case.Reason)
        );


        return result;
    }


    // =========================================================
    // Picklist Helper
    // =========================================================

    private static List<String> getPicklistValues(
        Schema.SObjectField field
    ) 
    {

        List<String> values =
            new List<String>();


        Schema.DescribeFieldResult fieldDescribe =
            field.getDescribe();


        for (
            Schema.PicklistEntry entry :
            fieldDescribe.getPicklistValues()
        ) {

            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }


        return values;
    }
}