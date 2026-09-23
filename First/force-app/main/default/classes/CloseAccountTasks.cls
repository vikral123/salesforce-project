public with sharing class CloseAccountTasks {

    public class Request {
        @InvocableVariable(required=true)
        public Id accountId;
    }

    @InvocableMethod(label='Close Account Tasks')
    public static void closeTasks(List<Request> requests) {

        Set<Id> accountIds = new Set<Id>();

        for (Request req : requests) {
            if (req.accountId != null) {
                accountIds.add(req.accountId);
            }
        }

        List<Task> tasks = [
            SELECT Id, Subject, Status
            FROM Task
            WHERE WhatId IN :accountIds
            AND IsClosed = false
        ];

        for (Task task : tasks) {
            task.Status = 'Completed';
        }

        if (!tasks.isEmpty()) {
            update tasks;
        }
    }
}