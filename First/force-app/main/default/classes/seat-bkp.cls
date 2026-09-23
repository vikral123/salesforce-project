public with sharing class SeatTriggerHandler {

    public static void preventDuplicateSeatName(List<Seat__c> newSeats) {
        Set<Id> floorIds = new Set<Id>();
        for (Seat__c s : newSeats) {
            if (s.Floor__c != null && String.isNotBlank(s.Name)) {
                floorIds.add(s.Floor__c);
            }
        }
        if (floorIds.isEmpty()) {
            return;
        }
        Map<String, Id> existingKeyToId = new Map<String, Id>();
        for (Seat__c existing : [
            SELECT Id, Name, Floor__c
            FROM Seat__c
            WHERE Floor__c IN :floorIds
        ]) {
            String normalizedName = existing.Name.replaceAll('\\s+', '').toLowerCase();
            String key = existing.Floor__c + '-' + normalizedName;
            existingKeyToId.put(key, existing.Id);
        }
        for (Seat__c s : newSeats) {
            if (s.Floor__c == null || String.isBlank(s.Name)) {
                continue;
            }
            String normalizedName = s.Name.replaceAll('\\s+', '').toLowerCase();
            String key = s.Floor__c + '-' + normalizedName;
            Id matchedId = existingKeyToId.get(key);
            if (matchedId != null && matchedId != s.Id) {
                s.addError('A seat with this name already exists on the selected floor (spaces/case ignored).');
                continue;
            }
            Integer countInBatch = 0;
            for (Seat__c other : newSeats) {
                if (other.Floor__c == s.Floor__c
                    && other.Name != null
                    && other.Name.replaceAll('\\s+', '').toLowerCase().equals(normalizedName)) {
                    countInBatch++;
                }
            }
            if (countInBatch > 1) {
                s.addError('Duplicate seat name found within the same floor in this operation.');
            }
        }
    }

    // NAYA METHOD - 50 seat limit check karne ke liye
    public static void preventExceedingFloorLimit(List<Seat__c> newSeats) {

        final Integer MAX_SEATS_PER_FLOOR = 50;

        Set<Id> floorIds = new Set<Id>();
        for (Seat__c s : newSeats) {
            if (s.Floor__c != null) {
                floorIds.add(s.Floor__c);
            }
        }

        if (floorIds.isEmpty()) return;

        Map<Id, Integer> existingCountByFloor = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Floor__c fId, COUNT(Id) total
            FROM Seat__c
            WHERE Floor__c IN :floorIds
            GROUP BY Floor__c
        ]) {
            existingCountByFloor.put((Id) ar.get('fId'), (Integer) ar.get('total'));
        }

        Map<Id, Integer> newCountByFloor = new Map<Id, Integer>();

        for (Seat__c s : newSeats) {
            if (s.Floor__c == null) continue;

            Integer existing = existingCountByFloor.containsKey(s.Floor__c)
                ? existingCountByFloor.get(s.Floor__c)
                : 0;

            Integer alreadyAddedInThisBatch = newCountByFloor.containsKey(s.Floor__c)
                ? newCountByFloor.get(s.Floor__c)
                : 0;

            Integer totalIfAdded = existing + alreadyAddedInThisBatch + 1;

            if (totalIfAdded > MAX_SEATS_PER_FLOOR) {
                s.addError('This floor has already reached the maximum limit of '
                    + MAX_SEATS_PER_FLOOR + ' seats. Cannot create more.');
            } else {
                newCountByFloor.put(s.Floor__c, alreadyAddedInThisBatch + 1);
            }
        }
    }
}

.career-inner-from label {
    color: black !important;
}
.career-inner-from input {
    border: 1px solid !important;
}