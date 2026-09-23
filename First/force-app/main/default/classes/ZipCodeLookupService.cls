public with sharing class ZipCodeLookupService {
    @AuraEnabled
    public static Map<String, String> getCityState(String zipCode) {
        Map<String, String> result = new Map<String, String>();
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.zippopotam.us/in/' + zipCode);
            req.setMethod('GET');
            req.setTimeout(10000);

            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> places = (List<Object>) body.get('places');
                if (!places.isEmpty()) {
                    Map<String, Object> place = (Map<String, Object>) places[0]; //places[0] ke andar jo data hai, usko Map<String, Object> ke roop mein treat karo.
                    result.put('city', (String) place.get('place name'));//place Map ke andar "place name" key ko search kar raha hai.
                    result.put('state', (String) place.get('state'));
                }
            } else {
                result.put('error', 'Invalid Zip Code');
            }
        } catch (Exception e) {
            result.put('error', e.getMessage());
        }
        return result;
    }
}