import { LightningElement, api } from 'lwc';
import getCases from '@salesforce/apex/CaseManagerController.getCases';
import createCase from '@salesforce/apex/CaseManagerController.createCase';
import updateCaseStatus from '@salesforce/apex/CaseManagerController.updateCaseStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CaseManager extends LightningElement {
    @api recordId;
    cases = [];   
    draftValues = [];
    searchKey = ''; 
    status = 'All';
    priority = 'All';
    pageSize = 10; 
    currentPage = 1;
    totalRecords = 0;
    totalPages = 0;
    isLoading = false;  
    isSaving = false;
    showModal = false;
    initialLoadDone = false;
    searchTimeout;  
    newCase = {subject: '',description: '',priority: 'Medium',origin: 'Phone'};    // NEW CASE
    // DATATABLE COLUMNS
    columns = [
        {label: 'Case Number',fieldName: 'caseUrl',type: 'url',
            typeAttributes: {label: {fieldName: 'CaseNumber'},target: '_blank'}
        },
        {label: 'Subject',fieldName: 'Subject',type: 'text'},
        {label: 'Status',fieldName: 'Status', type: 'text', editable: true},
        {label: 'Priority',fieldName: 'Priority',type: 'text'},
        {label: 'Origin',fieldName: 'Origin',type: 'text'},
        {label: 'Created Date',fieldName: 'CreatedDate',type: 'date', typeAttributes: {year: 'numeric',month: 'short',day: '2-digit',hour: '2-digit',minute: '2-digit'}},
        {label: 'Owner',fieldName: 'OwnerName',type: 'text'}
    ];
    // STATUS OPTIONS
    statusOptions = [
        {label: 'All',value: 'All'},
        {label: 'New',value: 'New'},
        {label: 'Working',value: 'Working'},
        {label: 'Escalated',value: 'Escalated'},
        {label: 'Closed',value: 'Closed'}
    ];
    // PRIORITY OPTIONS - FILTER
    priorityOptions = [
        {label: 'All',value: 'All'},{label: 'High',value: 'High'},
        {label: 'Medium',value: 'Medium'},
        {label: 'Low',value: 'Low'}
    ];
    // PRIORITY OPTIONS - CREATE
    priorityOptionsForCreate = [
        {label: 'High',value: 'High'},
        {label: 'Medium',value: 'Medium'},
        {label: 'Low',value: 'Low'}
    ];
    // ORIGIN OPTIONS
    originOptions = [
        {label: 'Phone',value: 'Phone'},
        {label: 'Email', value: 'Email'},
        {label: 'Web', value: 'Web'}
    ];
    // LOAD CASES
    async loadCases() {
        if (!this.recordId) {
            return;
        }
        this.isLoading = true;
        try {
            const result = await getCases({
                accountId: this.recordId,
                searchKey: this.searchKey,
                status: this.status,
                priority: this.priority,
                pageNumber: this.currentPage,
                pageSize: this.pageSize
            });
            this.totalRecords = result?.totalRecords || 0;
            this.currentPage = result?.pageNumber || 1;
            this.totalPages = result?.totalPages || 0;
            this.cases =
                (result?.records || []).map(
                    item => {
                        return {
                            ...item, caseUrl:'/' + item.Id, OwnerName:item.Owner ? item.Owner.Name : ''
                        };
                    }
                );
        }
        catch (error) {
            this.showToast('Error',this.getErrorMessage(error),'error');
        }
        finally {
            this.isLoading = false;
        }
    }
    // SEARCH
    handleSearch(event) {
        this.searchKey = event.target.value;
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            this.currentPage = 1;
            this.loadCases();
        }, 400);
    }
    // STATUS FILTER
    handleStatusChange(event) {
        this.status = event.detail.value;
        this.currentPage = 1;
        this.loadCases();
    }
    // PRIORITY FILTER
    handlePriorityChange(event) {
        this.priority = event.detail.value;
        this.currentPage = 1;
        this.loadCases();
    }
    // CLEAR FILTERS
    clearFilters() {
        clearTimeout(this.searchTimeout);
        this.searchKey = '';
        this.status = 'All';
        this.priority = 'All';
        this.currentPage = 1;
        const searchInput = this.template.querySelector('lightning-input[type="search"]');
        if (searchInput) {
            searchInput.value = '';
        }
        this.loadCases();
    }
    // PREVIOUS
    handlePrevious() {
        if (this.currentPage > 1 && !this.isLoading) {
            this.currentPage--;// this means decrease the current page value 1
            this.loadCases();
        }
    }
    // NEXT
    handleNext() {
        if (this.currentPage < this.totalPages && !this.isLoading) {
            this.currentPage++;
            this.loadCases();
        }
    }
    // DISABLE PREVIOUS
    get disablePrevious() {
        return (this.isLoading || this.currentPage <= 1 || this.totalPages === 0);
    }
    // DISABLE NEXT
    get disableNext() {
        return (this.isLoading || this.currentPage >= this.totalPages || this.totalPages === 0);
    }
    // NO RECORDS
    get showNoRecords() {
        return (!this.isLoading && this.cases.length === 0);
    }
    openNewCaseModal() {
        this.newCase = {
            subject: '',
            description: '',
            priority: 'Medium',
            origin: 'Phone'
        };
        this.showModal = true;
    }
    // CLOSE MODAL
    closeModal() {
        if (!this.isSaving) {
            this.showModal = false;
        }
    }
    // NEW CASE INPUT CHANGE
    handleNewCaseChange(event) {
        const fieldName = event.target.name;
        const value = event.detail?.value ?? event.target.value;
        this.newCase = {
            ...this.newCase,
            [fieldName]: value
        };
    }

    // SAVE NEW CASE
    async saveCase() {
        // SUBJECT VALIDATION
        const subject = this.newCase?.subject ? this.newCase.subject.trim(): '';
        if (!subject) {
            this.showToast('Error','Case Subject is required.','error');
            return;
        }

        // ACCOUNT VALIDATION
        if (!this.recordId) {
            console.error('Account Record Id is missing');
            this.showToast('Error','Account Id is missing. Please open this component from an Account record.','error');
            return;
        }

        // START SAVING
        this.isSaving = true;
        try {
            // APEX CALL
            const createdCase = await createCase({
                accountId:this.recordId,
                subject:subject,
                description:this.newCase.description || '',
                priority:this.newCase.priority || 'Medium',
                origin:this.newCase.origin || 'Phone'
            });

            this.showModal = false;   // CLOSE MODAL
            this.showToast('Success',`Case ${createdCase.CaseNumber} created successfully.`,'success'); // TOAST

            // RESET FORM
            this.newCase = {
                subject: '',
                description: '',
                priority: 'Medium',
                origin: 'Phone'
            };

            // REFRESH
            this.currentPage = 1;
            await this.loadCases();
        }
        catch (error) {
            this.showToast('Error',this.getErrorMessage(error),'error');
        }
        finally {
            this.isSaving = false;
        }
    }
    // INLINE STATUS UPDATE
    async handleSave(event) {
        const drafts = event.detail.draftValues;
        if (!drafts || drafts.length === 0) {
            return;
        }

        this.isLoading = true;
        try {
            for (const draft of drafts) {
                if (draft.Id && draft.Status) {
                    await updateCaseStatus({caseId:draft.Id,status:draft.Status});
                }
            }
            this.showToast('Success','Case status updated successfully.','success')
            this.draftValues = [];
            await this.loadCases();
        }
        catch (error) {
            this.showToast('Error',this.getErrorMessage(error),'error');
        }
        finally {
            this.isLoading = false;
        }
    }

    // TOAST
    showToast(title,message,variant) {
        this.dispatchEvent(new ShowToastEvent({title,message,variant}));
    }

    // ERROR MESSAGE
    getErrorMessage(error) {
        if (!error) {
            return 'Unknown error occurred.';
        }

        if (error.body && error.body.message) {
            return error.body.message;
        }

        if (error.body && Array.isArray(error.body)) {
            return error.body.map(item => item.message).join(', ');
        }

        if (error.message) {
            return error.message;
        }

        return ('Something went wrong. Please try again.');
    }

    // INITIAL LOAD
    renderedCallback() { 
        if (this.recordId && !this.initialLoadDone) {
            this.initialLoadDone = true;
            this.loadCases();
        }
    }
}