/**
 * ================================================================
 * PdfTextExtractionService
 * ================================================================
 *
 * PDF.co PDF Text Extraction Service
 *
 * FLOW 1 - SMALLER FILES
 *
 * LWC
 *   |
 *   | Base64 PDF
 *   v
 * Apex
 *   |
 *   | 1. Upload PDF
 *   v
 * PDF.co /v1/file/upload/base64
 *   |
 *   | Temporary PDF URL
 *   v
 * PDF.co /v1/pdf/convert/to/text
 *   |
 *   | Extracted text
 *   v
 * LWC
 *
 *
 * FLOW 2 - LARGE FILES
 *
 * LWC
 *   |
 *   | getUploadTarget(fileName)
 *   v
 * Apex
 *   |
 *   | GET presigned URL
 *   v
 * PDF.co
 *   |
 *   | presignedUrl + fileUrl
 *   v
 * LWC
 *   |
 *   | PUT raw PDF directly to presignedUrl
 *   v
 * PDF.co S3 storage
 *   |
 *   | startAsyncConversion(fileUrl)
 *   v
 * PDF.co
 *   |
 *   | jobId
 *   v
 * LWC polls checkConversionJob(jobId)
 *
 *
 * API KEY
 *
 * Custom Metadata:
 *
 * Pdf_Co_Config__mdt
 *
 * Developer Name:
 * Default
 *
 * Field:
 * Api_Key__c
 *
 * ================================================================
 */
public with sharing class PdfTextExtractionService {

    // ================================================================
    // PDF.CO NAMED CREDENTIAL
    // ================================================================

    private static final String NAMED_CREDENTIAL = 'callout:PDF_CO';


    // ================================================================
    // PDF.CO ENDPOINTS
    // ================================================================

    private static final String UPLOAD_ENDPOINT =
        NAMED_CREDENTIAL + '/v1/file/upload/base64';

    private static final String CONVERT_ENDPOINT =
        NAMED_CREDENTIAL + '/v1/pdf/convert/to/text';

    private static final String PRESIGNED_URL_ENDPOINT =
        NAMED_CREDENTIAL + '/v1/file/upload/get-presigned-url';

    private static final String JOB_CHECK_ENDPOINT =
        NAMED_CREDENTIAL + '/v1/job/check';


    // ================================================================
    // LIMITS / TIMEOUTS
    // ================================================================

    /*
     * IMPORTANT:
     *
     * This is the BASE64 string limit, not the original PDF size.
     *
     * Base64 is approximately 33% larger than the original binary file.
     *
     * 15 MB PDF
     * approximately becomes
     * 20 MB base64.
     *
     * However, Salesforce synchronous Apex heap is only 6 MB.
     *
     * Therefore:
     *
     * DO NOT assume that a 15 MB PDF can actually pass through
     * extractText().
     *
     * For large PDFs use the presigned URL flow instead.
     */

    private static final Integer MAX_BASE64_CHARS =
        20 * 1024 * 1024;


    /*
     * Salesforce cumulative callout time is limited.
     *
     * Two calls are made in the normal base64 flow:
     *
     * 1. upload
     * 2. conversion
     *
     * Keep their timeout values within the overall transaction budget.
     */

    private static final Integer UPLOAD_TIMEOUT = 40000;

    private static final Integer CONVERT_TIMEOUT = 70000;

    private static final Integer PRESIGN_TIMEOUT = 20000;

    private static final Integer START_CONVERT_TIMEOUT = 30000;

    private static final Integer JOB_CHECK_TIMEOUT = 30000;


    // ================================================================
    // CUSTOM EXCEPTION
    // ================================================================

    public class PdfExtractionException extends Exception {}


    // ================================================================
    // RESULT WRAPPER
    // ================================================================

    public class ExtractionResult {

        @AuraEnabled
        public String extractedText;

        @AuraEnabled
        public Integer pageCount;

        @AuraEnabled
        public String errorMessage;

        @AuraEnabled
        public Boolean success;

        @AuraEnabled
        public Integer creditsUsed;

        @AuraEnabled
        public Integer remainingCredits;

        @AuraEnabled
        public String requestId;

        @AuraEnabled
        public Integer statusCode;
    }


    // ================================================================
    // CONVERSION RESPONSE
    // ================================================================

    private class ConversionResponse {

        String extractedText;

        Integer pageCount;

        Integer creditsUsed;

        Integer remainingCredits;

        String requestId;

        Integer statusCode;

        String jobId;
    }


    // ================================================================
    // PRESIGNED UPLOAD RESULT
    // ================================================================

    public class UploadTargetResult {

        @AuraEnabled
        public String presignedUrl;

        @AuraEnabled
        public String fileUrl;

        @AuraEnabled
        public String errorMessage;
    }


    // ================================================================
    // CONVERSION JOB RESULT
    // ================================================================

    public class ConversionJobResult {

        @AuraEnabled
        public String jobId;

        @AuraEnabled
        public String extractedText;

        @AuraEnabled
        public String errorMessage;

        @AuraEnabled
        public Boolean success;

        @AuraEnabled
        public Integer pageCount;

        @AuraEnabled
        public Integer creditsUsed;

        @AuraEnabled
        public Integer remainingCredits;

        @AuraEnabled
        public String requestId;

        @AuraEnabled
        public String status;
    }


    // ================================================================
    // JOB STATUS RESULT
    // ================================================================

    public class JobStatusResult {

        @AuraEnabled
        public String status;

        @AuraEnabled
        public String extractedText;

        @AuraEnabled
        public String errorMessage;

        @AuraEnabled
        public Boolean success;

        @AuraEnabled
        public Integer pageCount;

        @AuraEnabled
        public Integer creditsUsed;

        @AuraEnabled
        public Integer remainingCredits;

        @AuraEnabled
        public String jobId;
    }


    // ================================================================
    // MAIN METHOD CALLED BY LWC
    // ================================================================

    @AuraEnabled
    public static ExtractionResult extractText(
        String base64Pdf,
        String fileName
    ) {

        ExtractionResult result =
            new ExtractionResult();

        result.success = false;
        result.extractedText = null;
        result.pageCount = null;
        result.errorMessage = null;
        result.creditsUsed = null;
        result.remainingCredits = null;
        result.requestId = null;
        result.statusCode = null;


        System.debug(
            LoggingLevel.INFO,
            '================================================'
        );

        System.debug(
            LoggingLevel.INFO,
            'PdfTextExtractionService.extractText START'
        );

        System.debug(
            LoggingLevel.INFO,
            '================================================'
        );


        // ============================================================
        // VALIDATE PDF DATA
        // ============================================================

        if (String.isBlank(base64Pdf)) {

            result.errorMessage =
                'No PDF file data was received.';

            System.debug(
                LoggingLevel.ERROR,
                'extractText stopped: base64Pdf is blank.'
            );

            return result;
        }


        // ============================================================
        // DEFAULT FILE NAME
        // ============================================================

        if (String.isBlank(fileName)) {

            fileName = 'uploaded.pdf';
        }


        System.debug(
            LoggingLevel.INFO,
            'File name: ' + fileName
        );


        System.debug(
            LoggingLevel.INFO,
            'Base64 received: YES'
        );


        System.debug(
            LoggingLevel.INFO,
            'Base64 length: ' + base64Pdf.length()
        );


        // ============================================================
        // VALIDATE PDF EXTENSION
        // ============================================================

        if (!fileName.toLowerCase().endsWith('.pdf')) {

            result.errorMessage =
                'Only PDF files are supported.';

            return result;
        }


        // ============================================================
        // VALIDATE BASE64 SIZE
        // ============================================================

        if (base64Pdf.length() > MAX_BASE64_CHARS) {

            result.errorMessage =
                'This PDF is too large to process through Apex base64. ' +
                'Please use the presigned URL upload flow for large PDFs.';

            System.debug(
                LoggingLevel.ERROR,
                'Base64 size exceeded MAX_BASE64_CHARS. ' +
                'Length=' + base64Pdf.length()
            );

            return result;
        }


        try {

            // ========================================================
            // STEP 1
            // GET API KEY
            // ========================================================

            System.debug(
                LoggingLevel.INFO,
                '===== STEP 1: GET API KEY ====='
            );


            String apiKey =
                getApiKey();


            // ========================================================
            // STEP 2
            // UPLOAD PDF
            // ========================================================

            System.debug(
                LoggingLevel.INFO,
                '===== STEP 2: UPLOAD PDF ====='
            );


            String uploadedFileUrl =
                uploadBase64File(
                    base64Pdf,
                    fileName,
                    apiKey
                );


            if (String.isBlank(uploadedFileUrl)) {

                throw new PdfExtractionException(
                    'PDF.co upload succeeded but no file URL was returned.'
                );
            }


            System.debug(
                LoggingLevel.INFO,
                'PDF.co upload completed successfully.'
            );


            System.debug(
                LoggingLevel.INFO,
                'Temporary file URL received from PDF.co.'
            );


            // ========================================================
            // STEP 3
            // CONVERT PDF TO TEXT
            // ========================================================

            System.debug(
                LoggingLevel.INFO,
                '===== STEP 3: CONVERT PDF TO TEXT ====='
            );


            ConversionResponse conversion =
                convertToText(
                    uploadedFileUrl,
                    apiKey
                );


            // ========================================================
            // COPY RESPONSE DATA
            // ========================================================

            result.extractedText =
                conversion.extractedText;

            result.pageCount =
                conversion.pageCount;

            result.creditsUsed =
                conversion.creditsUsed;

            result.remainingCredits =
                conversion.remainingCredits;

            result.requestId =
                conversion.requestId;

            result.statusCode =
                conversion.statusCode;


            // ========================================================
            // CHECK TEXT
            // ========================================================

            if (String.isBlank(result.extractedText)) {

                result.success = false;

                result.errorMessage =
                    'PDF.co processed the PDF but no text was found. ' +
                    'The PDF may be scanned/image-based or may not contain ' +
                    'selectable text.';

                System.debug(
                    LoggingLevel.WARN,
                    'PDF.co returned no extracted text.'
                );

                return result;
            }


            // ========================================================
            // SUCCESS
            // ========================================================

            result.success = true;


            System.debug(
                LoggingLevel.INFO,
                '===== PDF EXTRACTION SUCCESS ====='
            );


            System.debug(
                LoggingLevel.INFO,
                'Page count: ' +
                String.valueOf(result.pageCount)
            );


            System.debug(
                LoggingLevel.INFO,
                'Credits used: ' +
                String.valueOf(result.creditsUsed)
            );


            System.debug(
                LoggingLevel.INFO,
                'Remaining credits: ' +
                String.valueOf(result.remainingCredits)
            );


            System.debug(
                LoggingLevel.INFO,
                'Request ID: ' +
                String.valueOf(result.requestId)
            );


            System.debug(
                LoggingLevel.INFO,
                'Extracted text length: ' +
                String.valueOf(result.extractedText.length())
            );


            return result;


        } catch (PdfExtractionException e) {

            result.success = false;

            result.errorMessage =
                e.getMessage();


            System.debug(
                LoggingLevel.ERROR,
                'PdfExtractionException: ' +
                e.getMessage()
            );


            return result;


        } catch (System.CalloutException e) {

            result.success = false;

            result.errorMessage =
                'The callout to PDF.co failed or timed out: ' +
                e.getMessage() +
                '. For large PDFs, use the presigned URL + async job flow.';


            System.debug(
                LoggingLevel.ERROR,
                'PDF.co CalloutException: ' +
                e.getMessage()
            );


            return result;


        } catch (Exception e) {

            result.success = false;

            result.errorMessage =
                'Unexpected error extracting PDF text: ' +
                e.getMessage();


            System.debug(
                LoggingLevel.ERROR,
                'Unexpected PDF extraction error: ' +
                e.getMessage()
            );


            System.debug(
                LoggingLevel.ERROR,
                e.getStackTraceString()
            );


            return result;
        }
    }


    // ================================================================
    // UPLOAD BASE64 PDF TO PDF.CO
    // ================================================================

    private static String uploadBase64File(
        String base64Pdf,
        String fileName,
        String apiKey
    ) {

        System.debug(
            LoggingLevel.INFO,
            'PDF.co upload endpoint: ' +
            UPLOAD_ENDPOINT
        );


        System.debug(
            LoggingLevel.INFO,
            'PDF.co upload file name: ' +
            fileName
        );


        System.debug(
            LoggingLevel.INFO,
            'PDF.co base64 length: ' +
            base64Pdf.length()
        );


        HttpRequest req =
            new HttpRequest();


        req.setEndpoint(
            UPLOAD_ENDPOINT
        );


        req.setMethod(
            'POST'
        );


        req.setHeader(
            'Content-Type',
            'application/json'
        );


        req.setHeader(
            'x-api-key',
            apiKey
        );


        req.setTimeout(
            UPLOAD_TIMEOUT
        );


        // ============================================================
        // REQUEST BODY
        // ============================================================

        Map<String, Object> body =
            new Map<String, Object>();


        body.put(
            'name',
            fileName
        );


        body.put(
            'file',
            base64Pdf
        );


        String requestBody =
            JSON.serialize(body);


        req.setBody(
            requestBody
        );


        System.debug(
            LoggingLevel.INFO,
            'Sending PDF.co base64 upload request...'
        );


        // ============================================================
        // SEND REQUEST
        // ============================================================

        Http http =
            new Http();


        HttpResponse res =
            http.send(req);


        Integer statusCode =
            res.getStatusCode();


        String responseBody =
            res.getBody();


        System.debug(
            LoggingLevel.INFO,
            'PDF.co upload HTTP status: ' +
            statusCode
        );


        System.debug(
            LoggingLevel.DEBUG,
            'PDF.co upload response: ' +
            responseBody
        );


        // ============================================================
        // HTTP STATUS CHECK
        // ============================================================

        if (
            statusCode < 200 ||
            statusCode >= 300
        ) {

            throw buildPdfCoException(
                'PDF upload',
                statusCode,
                responseBody
            );
        }


        // ============================================================
        // PARSE RESPONSE
        // ============================================================

        Map<String, Object> parsed;


        try {

            parsed =
                (Map<String, Object>)
                JSON.deserializeUntyped(
                    responseBody
                );


        } catch (Exception e) {

            throw new PdfExtractionException(
                'PDF.co upload returned invalid JSON.'
            );
        }


        // ============================================================
        // PDF.CO ERROR
        // ============================================================

        if (
            parsed.containsKey('error') &&
            parsed.get('error') == true
        ) {

            throw buildPdfCoException(
                'PDF upload',
                statusCode,
                responseBody
            );
        }


        // ============================================================
        // GET UPLOAD URL
        // ============================================================

        String uploadedUrl = null;


        if (
            parsed.containsKey('url') &&
            parsed.get('url') != null
        ) {

            uploadedUrl =
                String.valueOf(
                    parsed.get('url')
                );
        }


        // ============================================================
        // VALIDATE URL
        // ============================================================

        if (String.isBlank(uploadedUrl)) {

            throw new PdfExtractionException(
                'PDF.co upload succeeded but did not return a temporary PDF URL.'
            );
        }


        System.debug(
            LoggingLevel.INFO,
            'PDF.co temporary file URL received.'
        );


        return uploadedUrl;
    }


    // ================================================================
    // CONVERT PDF TO TEXT - SYNCHRONOUS
    // ================================================================

    private static ConversionResponse convertToText(
        String fileUrl,
        String apiKey
    ) {

        HttpRequest req =
            new HttpRequest();


        req.setEndpoint(
            CONVERT_ENDPOINT
        );


        req.setMethod(
            'POST'
        );


        req.setHeader(
            'Content-Type',
            'application/json'
        );


        req.setHeader(
            'x-api-key',
            apiKey
        );


        req.setTimeout(
            CONVERT_TIMEOUT
        );


        System.debug(
            LoggingLevel.INFO,
            'PDF.co conversion endpoint: ' +
            CONVERT_ENDPOINT
        );


        System.debug(
            LoggingLevel.INFO,
            'PDF.co conversion source URL received.'
        );


        // ============================================================
        // REQUEST BODY
        // ============================================================

        Map<String, Object> body =
            new Map<String, Object>();


        body.put(
            'url',
            fileUrl
        );


        body.put(
            'async',
            false
        );


        body.put(
            'inline',
            true
        );


        req.setBody(
            JSON.serialize(body)
        );


        System.debug(
            LoggingLevel.INFO,
            'Sending PDF.co PDF-to-text request...'
        );


        // ============================================================
        // SEND REQUEST
        // ============================================================

        Http http =
            new Http();


        HttpResponse res =
            http.send(req);


        Integer statusCode =
            res.getStatusCode();


        String responseBody =
            res.getBody();


        System.debug(
            LoggingLevel.INFO,
            'PDF.co conversion HTTP status: ' +
            statusCode
        );


        System.debug(
            LoggingLevel.DEBUG,
            'PDF.co conversion response: ' +
            responseBody
        );


        // ============================================================
        // HTTP ERROR
        // ============================================================

        if (
            statusCode < 200 ||
            statusCode >= 300
        ) {

            throw buildPdfCoException(
                'PDF text conversion',
                statusCode,
                responseBody
            );
        }


        // ============================================================
        // PARSE JSON
        // ============================================================

        Map<String, Object> parsed;


        try {

            parsed =
                (Map<String, Object>)
                JSON.deserializeUntyped(
                    responseBody
                );


        } catch (Exception e) {

            throw new PdfExtractionException(
                'PDF.co conversion returned invalid JSON.'
            );
        }


        // ============================================================
        // PDF.CO ERROR FLAG
        // ============================================================

        if (
            parsed.containsKey('error') &&
            parsed.get('error') == true
        ) {

            throw buildPdfCoException(
                'PDF text conversion',
                statusCode,
                responseBody
            );
        }


        ConversionResponse response =
            new ConversionResponse();


        response.statusCode =
            statusCode;


        // ============================================================
        // REQUEST ID
        // ============================================================

        if (
            parsed.containsKey('requestId') &&
            parsed.get('requestId') != null
        ) {

            response.requestId =
                String.valueOf(
                    parsed.get('requestId')
                );
        }


        // ============================================================
        // PAGE COUNT
        // ============================================================

        if (
            parsed.containsKey('pageCount') &&
            parsed.get('pageCount') != null
        ) {

            response.pageCount =
                parseInteger(
                    parsed.get('pageCount')
                );
        }


        // ============================================================
        // CREDITS USED
        // ============================================================

        if (
            parsed.containsKey('credits') &&
            parsed.get('credits') != null
        ) {

            response.creditsUsed =
                parseInteger(
                    parsed.get('credits')
                );
        }


        // ============================================================
        // REMAINING CREDITS
        // ============================================================

        if (
            parsed.containsKey('remainingCredits') &&
            parsed.get('remainingCredits') != null
        ) {

            response.remainingCredits =
                parseInteger(
                    parsed.get('remainingCredits')
                );
        }


        // ============================================================
        // EXTRACTED TEXT
        // ============================================================

        if (
            parsed.containsKey('body') &&
            parsed.get('body') != null
        ) {

            response.extractedText =
                String.valueOf(
                    parsed.get('body')
                );
        }


        System.debug(
            LoggingLevel.INFO,
            'PDF.co conversion parsing completed.'
        );


        return response;
    }


    // ================================================================
    // GET API KEY FROM CUSTOM METADATA
    // ================================================================

    private static String getApiKey() {

        Pdf_Co_Config__mdt config;


        System.debug(
            LoggingLevel.INFO,
            'Reading PDF.co API key from Custom Metadata...'
        );


        // ============================================================
        // GET CONFIG
        // ============================================================

        try {

            config =
                Pdf_Co_Config__mdt.getInstance(
                    'Default'
                );


        } catch (Exception e) {

            throw new PdfExtractionException(
                'Unable to read PDF.co configuration from Custom Metadata.'
            );
        }


        // ============================================================
        // CONFIG NOT FOUND
        // ============================================================

        if (config == null) {

            throw new PdfExtractionException(
                'PDF.co configuration not found. ' +
                'Create Pdf_Co_Config__mdt record with Developer Name "Default".'
            );
        }


        // ============================================================
        // API KEY EMPTY
        // ============================================================

        if (
            String.isBlank(config.Api_Key__c)
        ) {

            throw new PdfExtractionException(
                'PDF.co API Key is missing. ' +
                'Populate Api_Key__c in Pdf_Co_Config__mdt.'
            );
        }


        String apiKey =
            config.Api_Key__c.trim();


        // ============================================================
        // BASIC VALIDATION
        // ============================================================

        if (
            apiKey.length() < 10
        ) {

            throw new PdfExtractionException(
                'PDF.co API Key appears to be invalid. ' +
                'Please verify the key stored in Custom Metadata.'
            );
        }


        // ============================================================
        // NEVER LOG THE ACTUAL API KEY
        // ============================================================

        System.debug(
            LoggingLevel.INFO,
            'PDF.co API key loaded successfully. ' +
            'Key length: ' +
            apiKey.length()
        );


        return apiKey;
    }


    // ================================================================
    // PDF.CO ERROR HANDLER
    // ================================================================

    private static PdfExtractionException buildPdfCoException(
        String operation,
        Integer statusCode,
        String responseBody
    ) {

        String message =
            'Unknown PDF.co error';


        String errorCode =
            null;


        String credits =
            null;


        String remainingCredits =
            null;


        String requestId =
            null;


        Integer bodyInternalStatus =
            null;


        // ============================================================
        // PARSE ERROR RESPONSE
        // ============================================================

        try {

            Map<String, Object> errorResponse =
                (Map<String, Object>)
                JSON.deserializeUntyped(
                    responseBody
                );


            // ========================================================
            // MESSAGE
            // ========================================================

            if (
                errorResponse.containsKey('message') &&
                errorResponse.get('message') != null
            ) {

                message =
                    String.valueOf(
                        errorResponse.get('message')
                    );
            }


            // ========================================================
            // ERROR CODE
            // ========================================================

            if (
                errorResponse.containsKey('errorCode') &&
                errorResponse.get('errorCode') != null
            ) {

                errorCode =
                    String.valueOf(
                        errorResponse.get('errorCode')
                    );
            }


            // ========================================================
            // CREDITS
            // ========================================================

            if (
                errorResponse.containsKey('credits') &&
                errorResponse.get('credits') != null
            ) {

                credits =
                    String.valueOf(
                        errorResponse.get('credits')
                    );
            }


            // ========================================================
            // REMAINING CREDITS
            // ========================================================

            if (
                errorResponse.containsKey('remainingCredits') &&
                errorResponse.get('remainingCredits') != null
            ) {

                remainingCredits =
                    String.valueOf(
                        errorResponse.get('remainingCredits')
                    );
            }


            // ========================================================
            // REQUEST ID
            // ========================================================

            if (
                errorResponse.containsKey('requestId') &&
                errorResponse.get('requestId') != null
            ) {

                requestId =
                    String.valueOf(
                        errorResponse.get('requestId')
                    );
            }


            // ========================================================
            // PDF.CO INTERNAL STATUS
            // ========================================================

            if (
                errorResponse.containsKey('status') &&
                errorResponse.get('status') != null
            ) {

                bodyInternalStatus =
                    parseInteger(
                        errorResponse.get('status')
                    );
            }


        } catch (Exception ignored) {

            // Response was not valid JSON.
        }


        // ============================================================
        // CREDIT ERROR
        // ============================================================

        Boolean isCreditError =
            (
                statusCode == 402
            )
            ||
            (
                errorCode == '402'
            )
            ||
            (
                message != null &&
                message.toLowerCase().contains(
                    'not enough credits'
                )
            );


        if (isCreditError) {

            String creditMessage =
                operation +
                ' failed (HTTP 402): PDF.co reports "Not enough credits".';


            if (credits != null) {

                creditMessage +=
                    ' Credits required for this call: ' +
                    credits +
                    '.';
            }


            if (remainingCredits != null) {

                creditMessage +=
                    ' Account remaining credits: ' +
                    remainingCredits +
                    '.';
            }


            /*
             * Important diagnostic:
             *
             * credits = 0
             * remainingCredits > 0
             *
             * This is usually NOT a genuine balance shortage.
             *
             * It can indicate:
             *
             * - endpoint restriction
             * - account/plan restriction
             * - API key belongs to another account
             * - operation is not enabled
             */

            if (
                credits == '0' &&
                remainingCredits != null &&
                remainingCredits != '0'
            ) {

                creditMessage +=
                    ' IMPORTANT: PDF.co returned required credits = 0 ' +
                    'while remaining credits are non-zero. ' +
                    'This does not look like a normal balance shortage. ' +
                    'Verify that the API key stored in Salesforce belongs ' +
                    'to the PDF.co account/subscription you are checking ' +
                    'and that this endpoint is enabled for that plan.';
            }


            if (requestId != null) {

                creditMessage +=
                    ' PDF.co Request ID: ' +
                    requestId +
                    '.';
            }


            if (bodyInternalStatus != null) {

                creditMessage +=
                    ' PDF.co internal status: ' +
                    bodyInternalStatus +
                    '.';
            }


            System.debug(
                LoggingLevel.ERROR,
                creditMessage
            );


            return new PdfExtractionException(
                creditMessage
            );
        }


        // ============================================================
        // TIMEOUT ERROR
        // ============================================================

        if (
            statusCode == 445
        ) {

            String timeoutMessage =
                operation +
                ' failed (HTTP 445): PDF.co timed out the operation. ' +
                'For large or many-page PDFs, use async=true and ' +
                '/v1/job/check instead of synchronous conversion.';


            if (requestId != null) {

                timeoutMessage +=
                    ' PDF.co Request ID: ' +
                    requestId +
                    '.';
            }


            System.debug(
                LoggingLevel.ERROR,
                timeoutMessage
            );


            return new PdfExtractionException(
                timeoutMessage
            );
        }


        // ============================================================
        // UNAUTHORIZED
        // ============================================================

        if (
            statusCode == 401 ||
            statusCode == 403
        ) {

            String authMessage =
                operation +
                ' failed (HTTP ' +
                statusCode +
                '): PDF.co rejected the request. ' +
                'Verify the API key, PDF.co account, and endpoint permissions.';


            if (requestId != null) {

                authMessage +=
                    ' PDF.co Request ID: ' +
                    requestId +
                    '.';
            }


            System.debug(
                LoggingLevel.ERROR,
                authMessage
            );


            return new PdfExtractionException(
                authMessage
            );
        }


        // ============================================================
        // GENERIC ERROR
        // ============================================================

        String finalMessage =
            operation +
            ' failed (HTTP ' +
            statusCode +
            '). ' +
            message;


        if (errorCode != null) {

            finalMessage +=
                ' Error code: ' +
                errorCode +
                '.';
        }


        if (credits != null) {

            finalMessage +=
                ' Credits: ' +
                credits +
                '.';
        }


        if (remainingCredits != null) {

            finalMessage +=
                ' Remaining credits: ' +
                remainingCredits +
                '.';
        }


        if (requestId != null) {

            finalMessage +=
                ' Request ID: ' +
                requestId +
                '.';
        }


        if (bodyInternalStatus != null) {

            finalMessage +=
                ' PDF.co internal status: ' +
                bodyInternalStatus +
                '.';
        }


        System.debug(
            LoggingLevel.ERROR,
            'PDF.co error: ' +
            finalMessage
        );


        return new PdfExtractionException(
            finalMessage
        );
    }


    // ================================================================
    // PRESIGNED URL
    //
    // This does NOT send the PDF through Apex.
    //
    // LWC:
    //
    // 1. calls getUploadTarget()
    // 2. receives presignedUrl + fileUrl
    // 3. PUTs the raw PDF directly to presignedUrl
    //
    // PDF.co documents this flow for large temporary files.
    // ================================================================

    @AuraEnabled
    public static UploadTargetResult getUploadTarget(
        String fileName
    ) {

        UploadTargetResult result =
            new UploadTargetResult();


        result.presignedUrl = null;
        result.fileUrl = null;
        result.errorMessage = null;


        System.debug(
            LoggingLevel.INFO,
            '================================================'
        );


        System.debug(
            LoggingLevel.INFO,
            'getUploadTarget START'
        );


        try {

            // ========================================================
            // DEFAULT NAME
            // ========================================================

            if (String.isBlank(fileName)) {

                fileName =
                    'uploaded.pdf';
            }


            System.debug(
                LoggingLevel.INFO,
                'Presigned upload file name: ' +
                fileName
            );


            // ========================================================
            // VALIDATE EXTENSION
            // ========================================================

            if (
                !fileName.toLowerCase().endsWith('.pdf')
            ) {

                result.errorMessage =
                    'Only PDF files are supported.';

                return result;
            }


            // ========================================================
            // API KEY
            // ========================================================

            String apiKey =
                getApiKey();


            // ========================================================
            // ENDPOINT
            // ========================================================

            /*
             * PDF.co returns presignedUrl and url.
             *
             * The file itself must later be PUT to presignedUrl.
             */

            String endpoint =
                PRESIGNED_URL_ENDPOINT +
                '?name=' +
                EncodingUtil.urlEncode(
                    fileName,
                    'UTF-8'
                );


            System.debug(
                LoggingLevel.INFO,
                'Presigned URL endpoint: ' +
                PRESIGNED_URL_ENDPOINT
            );


            // ========================================================
            // REQUEST
            // ========================================================

            HttpRequest req =
                new HttpRequest();


            req.setEndpoint(
                endpoint
            );


            req.setMethod(
                'GET'
            );


            req.setHeader(
                'x-api-key',
                apiKey
            );


            req.setTimeout(
                PRESIGN_TIMEOUT
            );


            // ========================================================
            // SEND
            // ========================================================

            Http http =
                new Http();


            HttpResponse res =
                http.send(req);


            Integer statusCode =
                res.getStatusCode();


            String body =
                res.getBody();


            System.debug(
                LoggingLevel.INFO,
                'Presigned URL HTTP status: ' +
                statusCode
            );


            System.debug(
                LoggingLevel.DEBUG,
                'Presigned URL response: ' +
                body
            );


            // ========================================================
            // HTTP ERROR
            // ========================================================

            if (
                statusCode < 200 ||
                statusCode >= 300
            ) {

                throw buildPdfCoException(
                    'Requesting an upload URL',
                    statusCode,
                    body
                );
            }


            // ========================================================
            // PARSE
            // ========================================================

            Map<String, Object> parsed =
                (Map<String, Object>)
                JSON.deserializeUntyped(
                    body
                );


            // ========================================================
            // PDF.CO ERROR
            // ========================================================

            if (
                parsed.containsKey('error') &&
                parsed.get('error') == true
            ) {

                throw buildPdfCoException(
                    'Requesting an upload URL',
                    statusCode,
                    body
                );
            }


            // ========================================================
            // PRESIGNED URL
            // ========================================================

            if (
                parsed.containsKey('presignedUrl') &&
                parsed.get('presignedUrl') != null
            ) {

                result.presignedUrl =
                    String.valueOf(
                        parsed.get('presignedUrl')
                    );
            }


            // ========================================================
            // FILE URL
            // ========================================================

            if (
                parsed.containsKey('url') &&
                parsed.get('url') != null
            ) {

                result.fileUrl =
                    String.valueOf(
                        parsed.get('url')
                    );
            }


            // ========================================================
            // VALIDATE
            // ========================================================

            if (
                String.isBlank(result.presignedUrl)
            ) {

                throw new PdfExtractionException(
                    'PDF.co did not return presignedUrl.'
                );
            }


            if (
                String.isBlank(result.fileUrl)
            ) {

                throw new PdfExtractionException(
                    'PDF.co did not return the final file URL.'
                );
            }


            System.debug(
                LoggingLevel.INFO,
                'Presigned URL received successfully.'
            );


            System.debug(
                LoggingLevel.INFO,
                'Final file URL received successfully.'
            );


        } catch (PdfExtractionException e) {

            result.errorMessage =
                e.getMessage();


            System.debug(
                LoggingLevel.ERROR,
                'getUploadTarget error: ' +
                e.getMessage()
            );


        } catch (System.CalloutException e) {

            result.errorMessage =
                'PDF.co presigned URL callout failed: ' +
                e.getMessage();


            System.debug(
                LoggingLevel.ERROR,
                'getUploadTarget CalloutException: ' +
                e.getMessage()
            );


        } catch (Exception e) {

            result.errorMessage =
                'Unexpected error requesting an upload URL: ' +
                e.getMessage();


            System.debug(
                LoggingLevel.ERROR,
                e.getMessage()
            );


            System.debug(
                LoggingLevel.ERROR,
                e.getStackTraceString()
            );
        }


        return result;
    }


    // ================================================================
    // START ASYNC CONVERSION
    //
    // IMPORTANT:
    //
    // This method receives ONLY fileUrl.
    //
    // No PDF base64 enters Apex.
    //
    // This is intended for large PDFs.
    // ================================================================

    @AuraEnabled
    public static ConversionJobResult startAsyncConversion(
        String fileUrl
    ) {

        ConversionJobResult result =
            new ConversionJobResult();


        result.success = false;
        result.jobId = null;
        result.extractedText = null;
        result.errorMessage = null;
        result.pageCount = null;
        result.creditsUsed = null;
        result.remainingCredits = null;
        result.requestId = null;
        result.status = null;


        System.debug(
            LoggingLevel.INFO,
            '================================================'
        );


        System.debug(
            LoggingLevel.INFO,
            'startAsyncConversion START'
        );


        try {

            // ========================================================
            // VALIDATE
            // ========================================================

            if (String.isBlank(fileUrl)) {

                result.errorMessage =
                    'No uploaded file URL was provided.';

                return result;
            }


            // ========================================================
            // API KEY
            // ========================================================

            String apiKey =
                getApiKey();


            // ========================================================
            // REQUEST
            // ========================================================

            HttpRequest req =
                new HttpRequest();


            req.setEndpoint(
                CONVERT_ENDPOINT
            );


            req.setMethod(
                'POST'
            );


            req.setHeader(
                'Content-Type',
                'application/json'
            );


            req.setHeader(
                'x-api-key',
                apiKey
            );


            req.setTimeout(
                START_CONVERT_TIMEOUT
            );


            // ========================================================
            // ASYNC BODY
            // ========================================================

            Map<String, Object> body =
                new Map<String, Object>();


            body.put(
                'url',
                fileUrl
            );


            body.put(
                'async',
                true
            );


            /*
             * inline is false for async mode.
             *
             * PDF.co will provide a result URL after the job finishes.
             */

            body.put(
                'inline',
                false
            );


            req.setBody(
                JSON.serialize(body)
            );


            System.debug(
                LoggingLevel.INFO,
                'Starting PDF.co async PDF-to-text conversion...'
            );


            // ========================================================
            // SEND
            // ========================================================

            Http http =
                new Http();


            HttpResponse res =
                http.send(req);


            Integer statusCode =
                res.getStatusCode();


            String responseBody =
                res.getBody();


            System.debug(
                LoggingLevel.INFO,
                'Async conversion HTTP status: ' +
                statusCode
            );


            System.debug(
                LoggingLevel.DEBUG,
                'Async conversion response: ' +
                responseBody
            );


            // ========================================================
            // HTTP ERROR
            // ========================================================

            if (
                statusCode < 200 ||
                statusCode >= 300
            ) {

                throw buildPdfCoException(
                    'Starting PDF text conversion',
                    statusCode,
                    responseBody
                );
            }


            // ========================================================
            // PARSE
            // ========================================================

            Map<String, Object> parsed =
                (Map<String, Object>)
                JSON.deserializeUntyped(
                    responseBody
                );


            // ========================================================
            // PDF.CO ERROR
            // ========================================================

            if (
                parsed.containsKey('error') &&
                parsed.get('error') == true
            ) {

                throw buildPdfCoException(
                    'Starting PDF text conversion',
                    statusCode,
                    responseBody
                );
            }


            // ========================================================
            // JOB ID
            // ========================================================

            if (
                parsed.containsKey('jobId') &&
                parsed.get('jobId') != null
            ) {

                result.jobId =
                    String.valueOf(
                        parsed.get('jobId')
                    );
            }


            /*
             * Some PDF.co responses historically used jobid.
             */

            if (
                String.isBlank(result.jobId) &&
                parsed.containsKey('jobid') &&
                parsed.get('jobid') != null
            ) {

                result.jobId =
                    String.valueOf(
                        parsed.get('jobid')
                    );
            }


            // ========================================================
            // STATUS
            // ========================================================

            if (
                parsed.containsKey('status') &&
                parsed.get('status') != null
            ) {

                result.status =
                    String.valueOf(
                        parsed.get('status')
                    );
            }


            // ========================================================
            // CREDITS
            // ========================================================

            if (
                parsed.containsKey('credits') &&
                parsed.get('credits') != null
            ) {

                result.creditsUsed =
                    parseInteger(
                        parsed.get('credits')
                    );
            }


            // ========================================================
            // REMAINING CREDITS
            // ========================================================

            if (
                parsed.containsKey('remainingCredits') &&
                parsed.get('remainingCredits') != null
            ) {

                result.remainingCredits =
                    parseInteger(
                        parsed.get('remainingCredits')
                    );
            }


            // ========================================================
            // REQUEST ID
            // ========================================================

            if (
                parsed.containsKey('requestId') &&
                parsed.get('requestId') != null
            ) {

                result.requestId =
                    String.valueOf(
                        parsed.get('requestId')
                    );
            }


            // ========================================================
            // VALIDATE JOB ID
            // ========================================================

            if (
                String.isBlank(result.jobId)
            ) {

                throw new PdfExtractionException(
                    'PDF.co accepted the conversion request but did not return a jobId.'
                );
            }


            result.success = true;


            System.debug(
                LoggingLevel.INFO,
                'PDF.co async conversion started successfully.'
            );


            System.debug(
                LoggingLevel.INFO,
                'Job ID: ' +
                result.jobId
            );


            return result;


        } catch (PdfExtractionException e) {

            result.success = false;

            result.errorMessage =
                e.getMessage();


            System.debug(
                LoggingLevel.ERROR,
                'startAsyncConversion error: ' +
                e.getMessage()
            );


        } catch (System.CalloutException e) {

            result.success = false;

            result.errorMessage =
                'PDF.co async conversion callout failed: ' +
                e.getMessage();


            System.debug(
                LoggingLevel.ERROR,
                'startAsyncConversion CalloutException: ' +
                e.getMessage()
            );


        } catch (Exception e) {

            result.success = false;

            result.errorMessage =
                'Unexpected error starting PDF conversion: ' +
                e.getMessage();


            System.debug(
                LoggingLevel.ERROR,
                e.getMessage()
            );


            System.debug(
                LoggingLevel.ERROR,
                e.getStackTraceString()
            );
        }


        return result;
    }


    // ================================================================
    // BACKWARD-COMPATIBLE METHOD
    //
    // This method is kept because your existing LWC may already call:
    //
    // startConversion(fileUrl)
    //
    // It performs SYNCHRONOUS conversion.
    //
    // For large files use:
    //
    // startAsyncConversion(fileUrl)
    // + checkConversionJob(jobId)
    // ================================================================

    @AuraEnabled
    public static ConversionJobResult startConversion(
        String fileUrl
    ) {

        ConversionJobResult result =
            new ConversionJobResult();


        result.success = false;
        result.jobId = null;
        result.extractedText = null;
        result.errorMessage = null;
        result.pageCount = null;
        result.creditsUsed = null;
        result.remainingCredits = null;
        result.requestId = null;
        result.status = null;


        try {

            if (String.isBlank(fileUrl)) {

                result.errorMessage =
                    'No uploaded file URL was provided.';

                return result;
            }


            String apiKey =
                getApiKey();


            HttpRequest req =
                new HttpRequest();


            req.setEndpoint(
                CONVERT_ENDPOINT
            );


            req.setMethod(
                'POST'
            );


            req.setHeader(
                'Content-Type',
                'application/json'
            );


            req.setHeader(
                'x-api-key',
                apiKey
            );


            req.setTimeout(
                CONVERT_TIMEOUT
            );


            Map<String, Object> body =
                new Map<String, Object>();


            body.put(
                'url',
                fileUrl
            );


            body.put(
                'async',
                false
            );


            body.put(
                'inline',
                true
            );


            req.setBody(
                JSON.serialize(body)
            );


            System.debug(
                LoggingLevel.INFO,
                'startConversion: sending synchronous PDF-to-text request.'
            );


            Http http =
                new Http();


            HttpResponse res =
                http.send(req);


            Integer statusCode =
                res.getStatusCode();


            String responseBody =
                res.getBody();


            System.debug(
                LoggingLevel.INFO,
                'startConversion HTTP status: ' +
                statusCode
            );


            System.debug(
                LoggingLevel.DEBUG,
                'startConversion response: ' +
                responseBody
            );


            if (
                statusCode < 200 ||
                statusCode >= 300
            ) {

                throw buildPdfCoException(
                    'PDF text conversion',
                    statusCode,
                    responseBody
                );
            }


            Map<String, Object> parsed =
                (Map<String, Object>)
                JSON.deserializeUntyped(
                    responseBody
                );


            if (
                parsed.containsKey('error') &&
                parsed.get('error') == true
            ) {

                throw buildPdfCoException(
                    'PDF text conversion',
                    statusCode,
                    responseBody
                );
            }


            result.status =
                'success';


            result.jobId =
                null;


            if (
                parsed.containsKey('body') &&
                parsed.get('body') != null
            ) {

                result.extractedText =
                    String.valueOf(
                        parsed.get('body')
                    );
            }


            if (
                parsed.containsKey('pageCount') &&
                parsed.get('pageCount') != null
            ) {

                result.pageCount =
                    parseInteger(
                        parsed.get('pageCount')
                    );
            }


            if (
                parsed.containsKey('credits') &&
                parsed.get('credits') != null
            ) {

                result.creditsUsed =
                    parseInteger(
                        parsed.get('credits')
                    );
            }


            if (
                parsed.containsKey('remainingCredits') &&
                parsed.get('remainingCredits') != null
            ) {

                result.remainingCredits =
                    parseInteger(
                        parsed.get('remainingCredits')
                    );
            }


            if (
                parsed.containsKey('requestId') &&
                parsed.get('requestId') != null
            ) {

                result.requestId =
                    String.valueOf(
                        parsed.get('requestId')
                    );
            }


            if (String.isBlank(result.extractedText)) {

                result.success = false;

                result.errorMessage =
                    'PDF.co processed the PDF but no text was found. ' +
                    'The PDF may be scanned/image-based or may not contain selectable text.';

                return result;
            }


            result.success = true;


            return result;


        } catch (PdfExtractionException e) {

            result.success = false;

            result.errorMessage =
                e.getMessage();


            return result;


        } catch (System.CalloutException e) {

            result.success = false;

            result.errorMessage =
                'PDF.co conversion callout failed: ' +
                e.getMessage();


            System.debug(
                LoggingLevel.ERROR,
                e.getMessage()
            );


            return result;


        } catch (Exception e) {

            result.success = false;

            result.errorMessage =
                'Unexpected error starting PDF conversion: ' +
                e.getMessage();


            System.debug(
                LoggingLevel.ERROR,
                e.getMessage()
            );


            System.debug(
                LoggingLevel.ERROR,
                e.getStackTraceString()
            );


            return result;
        }
    }


    // ================================================================
    // CHECK ASYNC CONVERSION JOB
    // ================================================================

    @AuraEnabled
    public static JobStatusResult checkConversionJob(
        String jobId
    ) {

        JobStatusResult result =
            new JobStatusResult();


        result.status = null;
        result.extractedText = null;
        result.errorMessage = null;
        result.success = false;
        result.pageCount = null;
        result.creditsUsed = null;
        result.remainingCredits = null;
        result.jobId = jobId;


        try {

            // ========================================================
            // VALIDATE JOB ID
            // ========================================================

            if (String.isBlank(jobId)) {

                result.errorMessage =
                    'No job ID was provided.';

                return result;
            }


            String apiKey =
                getApiKey();


            // ========================================================
            // REQUEST
            // ========================================================

            HttpRequest req =
                new HttpRequest();


            req.setEndpoint(
                JOB_CHECK_ENDPOINT
            );


            req.setMethod(
                'POST'
            );


            req.setHeader(
                'Content-Type',
                'application/json'
            );


            req.setHeader(
                'x-api-key',
                apiKey
            );


            req.setTimeout(
                JOB_CHECK_TIMEOUT
            );


            Map<String, Object> body =
                new Map<String, Object>();


            body.put(
                'jobid',
                jobId
            );


            req.setBody(
                JSON.serialize(body)
            );


            System.debug(
                LoggingLevel.INFO,
                'Checking PDF.co job: ' +
                jobId
            );


            // ========================================================
            // SEND
            // ========================================================

            Http http =
                new Http();


            HttpResponse res =
                http.send(req);


            Integer statusCode =
                res.getStatusCode();


            String responseBody =
                res.getBody();


            System.debug(
                LoggingLevel.INFO,
                'Job check HTTP status: ' +
                statusCode
            );


            System.debug(
                LoggingLevel.DEBUG,
                'Job check response: ' +
                responseBody
            );


            if (
                statusCode < 200 ||
                statusCode >= 300
            ) {

                throw buildPdfCoException(
                    'Checking conversion job status',
                    statusCode,
                    responseBody
                );
            }


            // ========================================================
            // PARSE
            // ========================================================

            Map<String, Object> parsed =
                (Map<String, Object>)
                JSON.deserializeUntyped(
                    responseBody
                );


            if (
                parsed.containsKey('error') &&
                parsed.get('error') == true
            ) {

                throw buildPdfCoException(
                    'Checking conversion job status',
                    statusCode,
                    responseBody
                );
            }


            // ========================================================
            // STATUS
            // ========================================================

            String jobStatus =
                parsed.containsKey('status')
                ? String.valueOf(
                    parsed.get('status')
                )
                : null;


            result.status =
                jobStatus;


            // ========================================================
            // CREDITS
            // ========================================================

            if (
                parsed.containsKey('credits') &&
                parsed.get('credits') != null
            ) {

                result.creditsUsed =
                    parseInteger(
                        parsed.get('credits')
                    );
            }


            // ========================================================
            // REMAINING CREDITS
            // ========================================================

            if (
                parsed.containsKey('remainingCredits') &&
                parsed.get('remainingCredits') != null
            ) {

                result.remainingCredits =
                    parseInteger(
                        parsed.get('remainingCredits')
                    );
            }


            // ========================================================
            // PAGE COUNT
            // ========================================================

            if (
                parsed.containsKey('pageCount') &&
                parsed.get('pageCount') != null
            ) {

                result.pageCount =
                    parseInteger(
                        parsed.get('pageCount')
                    );
            }


            // ========================================================
            // WORKING
            // ========================================================

            if (
                jobStatus == 'working'
            ) {

                result.success = false;

                return result;
            }


            // ========================================================
            // SUCCESS
            // ========================================================

            if (
                jobStatus == 'success'
            ) {

                String resultUrl =
                    parsed.containsKey('url')
                    ? String.valueOf(
                        parsed.get('url')
                    )
                    : null;


                if (
                    String.isBlank(resultUrl)
                ) {

                    throw new PdfExtractionException(
                        'PDF.co reported job success but did not return a result URL.'
                    );
                }


                /*
                 * PDF.co's async job result is a temporary file URL.
                 *
                 * We download the resulting text file here.
                 *
                 * This is NOT the original PDF.
                 */

                HttpRequest textReq =
                    new HttpRequest();


                textReq.setEndpoint(
                    resultUrl
                );


                textReq.setMethod(
                    'GET'
                );


                textReq.setTimeout(
                    JOB_CHECK_TIMEOUT
                );


                System.debug(
                    LoggingLevel.INFO,
                    'Downloading PDF.co conversion result...'
                );


                HttpResponse textRes =
                    http.send(
                        textReq
                    );


                Integer textStatus =
                    textRes.getStatusCode();


                if (
                    textStatus < 200 ||
                    textStatus >= 300
                ) {

                    throw new PdfExtractionException(
                        'PDF.co job completed, but extracted text ' +
                        'could not be downloaded. HTTP ' +
                        textStatus +
                        '.'
                    );
                }


                result.extractedText =
                    textRes.getBody();


                result.success = true;


                System.debug(
                    LoggingLevel.INFO,
                    'PDF.co async extraction completed successfully.'
                );


                System.debug(
                    LoggingLevel.INFO,
                    'Extracted text length: ' +
                    result.extractedText.length()
                );


                return result;
            }


            // ========================================================
            // FAILED
            // ========================================================

            if (
                jobStatus == 'failed' ||
                jobStatus == 'aborted'
            ) {

                String message =
                    parsed.containsKey('message')
                    ? String.valueOf(
                        parsed.get('message')
                    )
                    : 'PDF.co conversion job failed.';


                result.success = false;


                result.errorMessage =
                    'PDF.co conversion job ' +
                    jobStatus +
                    ': ' +
                    message;


                return result;
            }


            // ========================================================
            // UNKNOWN
            // ========================================================

            result.success = false;


            result.errorMessage =
                'PDF.co returned an unknown job status: ' +
                String.valueOf(jobStatus);


        } catch (PdfExtractionException e) {

            result.success = false;

            result.errorMessage =
                e.getMessage();


            System.debug(
                LoggingLevel.ERROR,
                'checkConversionJob error: ' +
                e.getMessage()
            );


        } catch (System.CalloutException e) {

            result.success = false;

            result.errorMessage =
                'PDF.co job check callout failed: ' +
                e.getMessage();


            System.debug(
                LoggingLevel.ERROR,
                e.getMessage()
            );


        } catch (Exception e) {

            result.success = false;

            result.errorMessage =
                'Unexpected error checking PDF.co job: ' +
                e.getMessage();


            System.debug(
                LoggingLevel.ERROR,
                e.getMessage()
            );


            System.debug(
                LoggingLevel.ERROR,
                e.getStackTraceString()
            );
        }


        return result;
    }


    // ================================================================
    // INTEGER PARSER
    // ================================================================

    private static Integer parseInteger(
        Object value
    ) {

        if (value == null) {

            return null;
        }


        try {

            return Integer.valueOf(
                String.valueOf(
                    value
                )
            );


        } catch (Exception e) {

            return null;
        }
    }
}