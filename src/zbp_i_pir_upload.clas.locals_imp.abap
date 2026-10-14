CLASS lhc_Upload DEFINITION
  INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.


METHODS UploadExcel
  FOR MODIFY
  IMPORTING keys FOR ACTION Upload~UploadExcel
  RESULT result.

METHODS ValidateData
  FOR MODIFY
  IMPORTING keys FOR ACTION Upload~ValidateData
  RESULT result.

METHODS ProcessUpload
  FOR MODIFY
  IMPORTING keys FOR ACTION Upload~ProcessUpload
  RESULT result.


METHODS AutoUploadOnCreate
  FOR DETERMINE ON SAVE
  IMPORTING keys
  FOR Upload~AutoUploadOnCreate.
METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
  keys REQUEST requested_authorizations FOR Upload RESULT result.
METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
  REQUEST requested_authorizations FOR upload RESULT result.

ENDCLASS.

CLASS lhc_upload IMPLEMENTATION.

METHOD UploadExcel.

  "------------------------------------------------
  "1. Read selected upload header
  "------------------------------------------------
  READ ENTITIES OF ZI_PIR_UPLOAD IN LOCAL MODE

    ENTITY Upload
    ALL FIELDS
    WITH CORRESPONDING #( keys )

    RESULT DATA(lt_headers)
    FAILED DATA(ls_read_failed).

  LOOP AT lt_headers INTO DATA(ls_header).

    "----------------------------------------------
    "2. Prevent processing an already uploaded batch
    "----------------------------------------------
    IF ls_header-UploadStatus = 'UPLOADED'
       OR ls_header-UploadStatus = 'VALIDATED'
       OR ls_header-UploadStatus = 'COMPLETED'.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-upload.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Batch already uploaded'
        )
      ) TO reported-upload.

      CONTINUE.

    ENDIF.

    "----------------------------------------------
    "3. Check Excel attachment
    "----------------------------------------------
    IF ls_header-FileContent IS INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-upload.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Please attach an Excel file'
        )
      ) TO reported-upload.

      CONTINUE.

    ENDIF.

    "----------------------------------------------
    "4. Read Excel using helper class
    "----------------------------------------------
    DATA lt_excel TYPE zcl_pir_excel=>tt_rows.
    DATA lv_error TYPE string.

    zcl_pir_excel=>read_excel(
      EXPORTING
        iv_file_content = ls_header-FileContent
      IMPORTING
        et_rows = lt_excel
        ev_error = lv_error
    ).

    IF lv_error IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-upload.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = lv_error
        )
      ) TO reported-upload.

      CONTINUE.

    ENDIF.

    "----------------------------------------------
    "5. Build parent-child RAP creation structure
    "----------------------------------------------
    DATA lt_create TYPE TABLE FOR CREATE
      ZI_PIR_UPLOAD\_Items.

    CLEAR lt_create.

    APPEND VALUE #(
      %tky = ls_header-%tky

      %target = VALUE #(
        FOR ls_excel IN lt_excel
        (
          %cid = |ROW{ ls_excel-row_no }|

          RowNo = ls_excel-row_no

          UploadAction = ls_excel-upload_action

          Supplier = ls_excel-supplier
          Material = ls_excel-material

          MaterialGroup = ls_excel-material_group

          PurchasingOrg = ls_excel-purchasing_org

          Plant = ls_excel-plant

          PurchasingGroup = ls_excel-purchasing_group

          PurchasingUoM = ls_excel-purchasing_uom

          PurchasePrice = ls_excel-purchase_price

          Currency = ls_excel-currency

          PriceUnit = ls_excel-price_unit

          ValidFrom =
            |{ ls_excel-valid_from+0(4) }{ ls_excel-valid_from+5(2) }{ ls_excel-valid_from+8(2) }|

          ValidTo =
            |{ ls_excel-valid_to+0(4) }{ ls_excel-valid_to+5(2) }{ ls_excel-valid_to+8(2) }|

          ConditionType = ls_excel-condition_type

          MRP = ls_excel-mrp

          TOTPercent = ls_excel-tot_percent

          MinimumQty = ls_excel-minimum_qty

          StandardOrderQty = ls_excel-standard_order_qty

          LeadTime = ls_excel-lead_time

          SupplierMaterial = ls_excel-supplier_material

          "ProcessStatus = 'UPLOADED'
ProcessStatus = ls_excel-process_status
          MessageText = ls_excel-message_text
        )
      )
    ) TO lt_create.

    "----------------------------------------------
    "6. Create the child records through RAP
    "----------------------------------------------
    "MODIFY ENTITIES OF ZI_PIR_UPLOAD IN LOCAL MODE

      "ENTITY Upload
      "CREATE BY \_Items
      "AUTO FILL CID

      "WITH lt_create

      "FAILED DATA(ls_create_failed)
      "REPORTED DATA(ls_create_reported).

MODIFY ENTITIES OF ZI_PIR_UPLOAD IN LOCAL MODE

  ENTITY Upload
  CREATE BY \_Items

  FIELDS (
    RowNo
    UploadAction
    Supplier
    Material
    MaterialGroup
    PurchasingOrg
    Plant
    PurchasingGroup
    PurchasingUoM
    PurchasePrice
    Currency
    PriceUnit
    ValidFrom
    ValidTo
    ConditionType
    MRP
    TOTPercent
    MinimumQty
    StandardOrderQty
    LeadTime
    SupplierMaterial
    ProcessStatus
    MessageText
  )

  WITH lt_create

  MAPPED DATA(ls_mapped)
  FAILED DATA(ls_create_failed)
  REPORTED DATA(ls_create_reported).

    IF ls_create_failed IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-upload.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Could not create upload items'
        )
      ) TO reported-upload.

      CONTINUE.

    ENDIF.

    "----------------------------------------------
    "7. Update upload header
    "----------------------------------------------
    MODIFY ENTITIES OF ZI_PIR_UPLOAD IN LOCAL MODE

      ENTITY Upload

      UPDATE FIELDS (
        UploadStatus
        TotalRecords
        SuccessRecords
        ErrorRecords
      )

      WITH VALUE #(
        (
          %tky = ls_header-%tky

          UploadStatus = 'UPLOADED'

          TotalRecords = lines( lt_excel )

          SuccessRecords = 0

          ErrorRecords = 0
        )
      )

      FAILED DATA(ls_update_failed)
      REPORTED DATA(ls_update_reported).

    IF ls_update_failed IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-upload.

      CONTINUE.

    ENDIF.

    "----------------------------------------------
    "8. Return refreshed header to Fiori
    "----------------------------------------------
    READ ENTITIES OF ZI_PIR_UPLOAD IN LOCAL MODE

      ENTITY Upload
      ALL FIELDS

      WITH VALUE #(
        ( %tky = ls_header-%tky )
      )

      RESULT DATA(lt_updated).

    IF lt_updated IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %param = lt_updated[ 1 ]
      ) TO result.

    ENDIF.

    APPEND VALUE #(
      %tky = ls_header-%tky
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-success
        text = |{ lines( lt_excel ) } Excel rows staged|
      )
    ) TO reported-upload.

  ENDLOOP.

ENDMETHOD.



METHOD ValidateData.

  LOOP AT keys INTO DATA(ls_key).

    APPEND VALUE #(
      %tky = ls_key-%tky
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-information
        text = 'Validation not implemented yet'
      )
    ) TO reported-upload.

  ENDLOOP.

ENDMETHOD.





METHOD ProcessUpload.

  "Read existing Excel items
  READ ENTITIES OF ZI_PIR_UPLOAD IN LOCAL MODE
    ENTITY Upload BY \_Items
    ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_items)
    FAILED DATA(ls_read_failed).

  IF ls_read_failed IS NOT INITIAL.
    RETURN.
  ENDIF.

  DATA lt_updates TYPE TABLE FOR UPDATE ZI_PIR_ITEM.

  LOOP AT lt_items INTO DATA(ls_item).

    "Do not repeat already completed records.
    "QUEUED records MUST be processed here.
    IF ls_item-ProcessStatus = 'SUCCESS'
       OR ls_item-ProcessStatus = 'ERROR'
       OR ls_item-ProcessStatus = 'PROCESSING'.
      CONTINUE.
    ENDIF.

    DATA(lv_action) =
      to_upper( CONV string( ls_item-UploadAction ) ).

    DATA(lv_cid) = CONV abp_behv_cid(
      |PIR{ ls_item-RowNo }| ).

    DATA(lv_status) = 'ERROR'.
    DATA(lv_message) = VALUE string( ).

    CASE lv_action.

      "========================================
      " CREATE PIR
      "========================================
      WHEN 'CREATE'.

        MODIFY ENTITIES OF I_PurchasingInfoRecordTP

          ENTITY PurchasingInfoRecord
          CREATE FIELDS (
            Supplier
            Material
            PurgDocOrderQuantityUnit
          )

          WITH VALUE #(
            (
              %cid = lv_cid
              Supplier = ls_item-Supplier
              Material = ls_item-Material
              PurgDocOrderQuantityUnit =
                ls_item-PurchasingUoM
            )
          )

          CREATE BY \_PurgInfoRecdOrgPlntData
          FIELDS (
            PurchasingInfoRecordCategory
            PurchasingOrganization
            Plant
            PurchasingGroup
            PriceValidityEndDate
            NetPriceAmount
            Currency
            MaterialPriceUnitQty
            MaterialPlannedDeliveryDurn
          )

          WITH VALUE #(
            (
              %cid_ref = lv_cid
              %target = VALUE #(
                (
                  %cid = |ORG{ ls_item-RowNo }|
                  PurchasingInfoRecordCategory = '0'
                  PurchasingOrganization =
                    ls_item-PurchasingOrg
                  Plant = ls_item-Plant
                  PurchasingGroup =
                    ls_item-PurchasingGroup
                  PriceValidityEndDate =
                    COND #(
                      WHEN ls_item-ValidTo IS NOT INITIAL
                      THEN ls_item-ValidTo
                      ELSE '99991231'
                    )
                  NetPriceAmount =
                    ls_item-PurchasePrice
                  Currency = ls_item-Currency
                  MaterialPriceUnitQty =
                    ls_item-PriceUnit
                  MaterialPlannedDeliveryDurn =
                    ls_item-LeadTime
                )
              )
            )
          )

          MAPPED DATA(ls_create_mapped)
          FAILED DATA(ls_create_failed)
          REPORTED DATA(ls_create_reported).

        IF ls_create_failed IS INITIAL.
          lv_status = 'PROCESSING'.
          lv_message =
            'CREATE EML accepted; save pending'.
        ELSE.
          lv_message = 'PIR CREATE EML failed'.

          LOOP AT ls_create_reported-purchasinginforecord
            INTO DATA(ls_create_msg).

            IF ls_create_msg-%msg IS BOUND.
              lv_message =
                ls_create_msg-%msg->if_message~get_text( ).
              EXIT.
            ENDIF.

          ENDLOOP.
        ENDIF.

      "========================================
      " UPDATE PIR
      "========================================

WHEN 'UPDATE'.

  IF ls_item-InfoRecord IS INITIAL.

    lv_status = 'ERROR'.

    lv_message =
      'Existing PIR number missing for UPDATE'.

  ELSE.

    MODIFY ENTITIES OF I_PurchasingInfoRecordTP

      ENTITY PurgInfoRecdOrgPlantData

      UPDATE FIELDS (
        PurchasingGroup
        MaterialPlannedDeliveryDurn
      )

      WITH VALUE #(
        (
          PurchasingInfoRecord = ls_item-InfoRecord

          PurchasingInfoRecordCategory = '0'

          PurchasingOrganization =
            ls_item-PurchasingOrg

          Plant = ls_item-Plant

          PurchasingGroup =
            ls_item-PurchasingGroup

          MaterialPlannedDeliveryDurn =
            ls_item-LeadTime
        )
      )

      FAILED DATA(ls_update_failed)
      REPORTED DATA(ls_update_reported).

    IF ls_update_failed IS INITIAL.

      lv_status = 'PROCESSING'.

      lv_message =
        'PIR UPDATE accepted; save pending'.

    ELSE.

      lv_status = 'ERROR'.

      lv_message = 'PIR UPDATE failed'.

    ENDIF.

  ENDIF.


      WHEN OTHERS.
        lv_message = 'Invalid CREATE/UPDATE action'.

    ENDCASE.

    "Write current processing result
    APPEND VALUE #(
      %tky = ls_item-%tky
      ProcessStatus = lv_status
      MessageText = lv_message
      %control-ProcessStatus = if_abap_behv=>mk-on
      %control-MessageText = if_abap_behv=>mk-on
    ) TO lt_updates.

  ENDLOOP.

  IF lt_updates IS NOT INITIAL.

    MODIFY ENTITIES OF ZI_PIR_UPLOAD IN LOCAL MODE
      ENTITY Item
      UPDATE FROM lt_updates
      FAILED DATA(ls_status_failed)
      REPORTED DATA(ls_status_reported).

  ENDIF.

  READ ENTITIES OF ZI_PIR_UPLOAD IN LOCAL MODE
    ENTITY Upload
    ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers).

  result = VALUE #(
    FOR ls_header IN lt_headers
    (
      %tky = ls_header-%tky
      %param = ls_header
    )
  ).

ENDMETHOD.



METHOD AutoUploadOnCreate.

  "----------------------------------------------
  "1. Read PIR upload header
  "----------------------------------------------
  READ ENTITIES OF ZI_PIR_UPLOAD IN LOCAL MODE
    ENTITY Upload
    FIELDS (
      FileContent
      FileName
      MimeType
      UploadStatus
    )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_uploads)
    FAILED DATA(ls_read_failed).

  IF ls_read_failed IS NOT INITIAL.
    RETURN.
  ENDIF.

  "----------------------------------------------
  "2. Process uploaded attachments
  "----------------------------------------------
  LOOP AT lt_uploads INTO DATA(ls_upload).

    IF ls_upload-FileContent IS INITIAL.
      CONTINUE.
    ENDIF.

    IF ls_upload-UploadStatus = 'UPLOADED'
       OR ls_upload-UploadStatus = 'COMPLETED'.
      CONTINUE.
    ENDIF.

    "--------------------------------------------
    "3. Execute existing UploadExcel action
    "--------------------------------------------
    MODIFY ENTITIES OF ZI_PIR_UPLOAD IN LOCAL MODE
      ENTITY Upload
      EXECUTE UploadExcel
      FROM VALUE #(
        (
          %tky = ls_upload-%tky
        )
      )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    "Inspect failures during integration testing
    IF ls_failed IS NOT INITIAL.
      CONTINUE.
    ENDIF.

  ENDLOOP.

ENDMETHOD.






  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

ENDCLASS.

*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

