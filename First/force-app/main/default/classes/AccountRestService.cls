@RestResource(urlMapping = '/v1/accounts/*')
global with sharing class AccountRestService{
    private static final String PHONE_PATTERN = '^[0-9]{10}$';
    @HttpGet
    global static void doGet(){
        RestResponse res = RestContext.response;
        try{
            String accountId = getIdFromUri();

            if (!isValidId(accountId)){
                setResponse(res, 400, 'A valid Account Id is required.');
                return;
            }

            List<Account> accounts = [SELECT Id, Name, Phone, Industry, AnnualRevenue, BillingCity, BillingCountry
                                      FROM Account
                                      WHERE Id = :accountId
                                      WITH SECURITY_ENFORCED
                                      LIMIT 1];

            if (accounts.isEmpty()){
                setResponse(res, 404, 'Account not found.');
                return;
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(accounts[0]));

        } catch (Exception e){
            setResponse(res, 500, 'Error fetching Account: ' + e.getMessage());
        }
    }

    @HttpPost
    global static void doPost(String name, String phone, String industry, Decimal annualRevenue){
        RestResponse res = RestContext.response;
        try{
            if (!Schema.sObjectType.Account.isCreateable()){
                setResponse(res, 403, 'No permission to create Account.');
                return;
            }

            if (String.isBlank(name)){
                setResponse(res, 400, 'Account Name is required.');
                return;
            }

            if (!String.isBlank(phone) && !Pattern.matches(PHONE_PATTERN, phone)){
                setResponse(res, 400, 'Phone number must contain exactly 10 digits and only numbers.');
                return;
            }

            if (isDuplicateName(name, null)){
                setResponse(res, 409, 'An Account with this name already exists.');
                return;
            }

            Account acc = new Account(
                Name = name, 
                Phone = phone, 
                Industry = industry, 
                AnnualRevenue = annualRevenue
            );

            insert acc;

            setResponse(res, 201, 'Account created successfully. Id: ' + acc.Id);

        } catch (DmlException e){
            setResponse(res, 400, 'Unable to create Account. ' + e.getDmlMessage(0));
        } catch (Exception e){
            setResponse(res, 500, 'Error creating Account: ' + e.getMessage());
        }
    }

    // ---------- PATCH ----------
    @HttpPatch
    global static void doPatch(String name, String phone, String industry, Decimal annualRevenue){
        RestResponse res = RestContext.response;
        try{
            if (!Schema.sObjectType.Account.isUpdateable()){
                setResponse(res, 403, 'No permission to update Account.');
                return;
            }

            String accountId = getIdFromUri();
            if (!isValidId(accountId)){
                setResponse(res, 400, 'A valid Account Id is required.');
                return;
            }

            List<Account> existing = [SELECT Id, Name, Phone, Industry, AnnualRevenue
                                      FROM Account
                                      WHERE Id = :accountId
                                      LIMIT 1];

            if (existing.isEmpty()){
                setResponse(res, 404, 'Account not found.');
                return;
            }

            Account acc = existing[0];

            if (!String.isBlank(phone) && !Pattern.matches(PHONE_PATTERN, phone)){
                setResponse(res, 400, 'Phone number must contain exactly 10 digits and only numbers.');
                return;
            }

            if (!String.isBlank(name)){

                if (name.trim().equalsIgnoreCase(acc.Name)){
                    setResponse(res, 409, 'Account name is already updated.');
                    return;
                }

                if (isDuplicateName(name, accountId)){
                    setResponse(res, 409, 'An Account with this name already exists.');
                    return;
                }

                acc.Name = name.trim();
            }

            if (phone != null)
                acc.Phone = phone;
            if (industry != null)
                acc.Industry = industry;
            if (annualRevenue != null)
                acc.AnnualRevenue = annualRevenue;
            update acc;

            setResponse(res, 200, 'Account updated successfully.');

        } catch (DmlException e){
            setResponse(res, 400, 'Unable to update Account. ' + e.getDmlMessage(0));
        } catch (Exception e){
            setResponse(res, 500, 'Error updating Account: ' + e.getMessage());
        }
    }

    // ---------- DELETE ----------
    @HttpDelete
    global static void doDelete(){
        RestResponse res = RestContext.response;
        try{
            if (!Schema.sObjectType.Account.isDeletable()){
                setResponse(res, 403, 'No permission to delete Account.');
                return;
            }

            String accountId = getIdFromUri();
            if (!isValidId(accountId)){
                setResponse(res, 400, 'A valid Account Id is required.');
                return;
            }

            List<Account> accounts = [SELECT Id
                                      FROM Account
                                      WHERE Id = :accountId
                                      LIMIT 1];

            if (accounts.isEmpty()){
                setResponse(res, 404, 'Account not found.');
                return;
            }

            delete accounts[0];

            setResponse(res, 200, 'Account deleted successfully.');

        } catch (DmlException e){
            setResponse(res, 400, 'Unable to delete Account. ' + e.getDmlMessage(0));
        } catch (Exception e){
            setResponse(res, 500, 'Error deleting Account: ' + e.getMessage());
        }
    }

    private static String getIdFromUri(){
        String uri = RestContext.request.requestURI;
        return uri.substring(uri.lastIndexOf('/') + 1);
    }

    private static Boolean isValidId(String recordId){
        if (String.isBlank(recordId)){
            return false;
        }

        return Pattern.matches('^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$', recordId);
    }

    private static Boolean isDuplicateName(String name, String excludeId){
        String query = 'SELECT COUNT() FROM Account WHERE Name = :name';
        if (excludeId != null){
            query += ' AND Id != :excludeId';
        }
        return Database.countQuery(query) > 0;
    }

    private static void setResponse(RestResponse res, Integer statusCode, String message){
        res.statusCode = statusCode;
        res.responseBody = Blob.valueOf(message);
    }

}