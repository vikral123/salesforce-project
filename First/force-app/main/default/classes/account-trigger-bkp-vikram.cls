trigger AccountTrigger on Account (before update, after update) {
    if (Trigger.isBefore) {
        AccountTriggerHandler.updateAccountRating(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        AccountTriggerHandler.syncContactPhoneFax(Trigger.new, Trigger.oldMap);
    }
}