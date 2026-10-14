
CLASS zcl_pir_excel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_row,
        row_no             TYPE i,
        upload_action      TYPE string,
        supplier           TYPE string,
        material           TYPE string,
        material_group     TYPE string,
        purchasing_org     TYPE string,
        plant              TYPE string,
        purchasing_group   TYPE string,
        purchasing_uom     TYPE string,
        purchase_price     TYPE string,
        currency           TYPE string,
        price_unit         TYPE string,
        valid_from         TYPE string,
        valid_to           TYPE string,
        condition_type     TYPE string,
        mrp                TYPE string,
        tot_percent        TYPE string,
        minimum_qty        TYPE string,
        standard_order_qty TYPE string,
        lead_time          TYPE string,
        supplier_material  TYPE string,
        process_status     TYPE string,
        message_text       TYPE string,
      END OF ty_row.

    TYPES tt_rows TYPE STANDARD TABLE OF ty_row
      WITH EMPTY KEY.

    CLASS-METHODS read_excel
      IMPORTING
        iv_file_content TYPE xstring
      EXPORTING
        et_rows         TYPE tt_rows
        ev_error        TYPE string.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_raw,
        c01 TYPE string,
        c02 TYPE string,
        c03 TYPE string,
        c04 TYPE string,
        c05 TYPE string,
        c06 TYPE string,
        c07 TYPE string,
        c08 TYPE string,
        c09 TYPE string,
        c10 TYPE string,
        c11 TYPE string,
        c12 TYPE string,
        c13 TYPE string,
        c14 TYPE string,
        c15 TYPE string,
        c16 TYPE string,
        c17 TYPE string,
        c18 TYPE string,
        c19 TYPE string,
        c20 TYPE string,
      END OF ty_raw.

    TYPES tt_raw TYPE STANDARD TABLE OF ty_raw
      WITH EMPTY KEY.

    CLASS-METHODS check_row
      CHANGING
        cs_row TYPE ty_row.

ENDCLASS.


CLASS zcl_pir_excel IMPLEMENTATION.

  METHOD read_excel.

    CLEAR: et_rows, ev_error.

    "==========================================
    "1. Verify uploaded file
    "==========================================

    IF iv_file_content IS INITIAL.
      ev_error = 'Please attach an XLSX file'.
      RETURN.
    ENDIF.

    DATA lt_raw TYPE tt_raw.

    "==========================================
    "2. Read XLSX using XCO
    "==========================================
TRY.

    "1. Get Excel document
    DATA(lo_document) =
      xco_cp_xlsx=>document->for_file_content(
        iv_file_content = iv_file_content ).

    "2. Create read access
    DATA(lo_read_access) =
      lo_document->read_access( ).

    "3. Get first worksheet
    DATA(lo_worksheet) =
      lo_read_access->get_workbook(
        )->worksheet->at_position( 1 ).

    "4. Select worksheet
    DATA(lo_pattern) =
      xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).

    "5. Read Excel into internal table
    DATA(lo_operation) =
      lo_worksheet->select( lo_pattern
        )->row_stream(
        )->operation->write_to(
          REF #( lt_raw ) ).

    "6. Convert cell values to strings
    lo_operation->set_value_transformation(
      xco_cp_xlsx_read_access=>value_transformation->string_value
    ).

    "7. Execute
    lo_operation->if_xco_xlsx_ra_operation~execute( ).

  CATCH cx_root INTO DATA(lx_error).

    ev_error = lx_error->get_text( ).
    RETURN.

ENDTRY.


    "==========================================
    "3. Verify Excel contains records
    "==========================================

    IF lines( lt_raw ) < 2.
      ev_error = 'Excel has no data rows'.
      RETURN.
    ENDIF.

    "==========================================
    "4. Verify existing 20-column template
    "==========================================

    DATA(lt_headers) = VALUE string_table(
      ( `Action` )
      ( `Supplier` )
      ( `Article` )
      ( `Material Group` )
      ( `Purchasing Org` )
      ( `Plant` )
      ( `Purchasing Group` )
      ( `Purchasing UoM` )
      ( `Purchase Price` )
      ( `Currency` )
      ( `Price Unit` )
      ( `Valid From` )
      ( `Valid To` )
      ( `Condition Type` )
      ( `MRP` )
      ( `TOT %` )
      ( `MOQ` )
      ( `Standard Order Qty` )
      ( `Lead Time` )
      ( `Supplier Material` )
    ).

    DATA(ls_header) = lt_raw[ 1 ].

    FIELD-SYMBOLS <cell> TYPE any.

    LOOP AT lt_headers INTO DATA(lv_header).

      DATA(lv_col) = sy-tabix.

      ASSIGN COMPONENT lv_col
        OF STRUCTURE ls_header TO <cell>.

      IF sy-subrc <> 0.
        ev_error = 'Invalid template structure'.
        RETURN.
      ENDIF.

      DATA(lv_actual) =
        to_upper(
          condense( CONV string( <cell> ) )
        ).

      IF lv_actual <> to_upper( lv_header ).

        ev_error =
          |Column { lv_col }: Expected { lv_header }|.

        RETURN.

      ENDIF.

    ENDLOOP.

    "==========================================
    "5. Read all Excel rows
    "==========================================

    LOOP AT lt_raw INTO DATA(ls_raw) FROM 2.

      DATA(lv_row_no) = sy-tabix.

      IF ls_raw IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(ls_row) = VALUE ty_row(

        row_no             = lv_row_no
        upload_action      = ls_raw-c01
        supplier           = ls_raw-c02
        material           = ls_raw-c03
        material_group     = ls_raw-c04
        purchasing_org     = ls_raw-c05
        plant              = ls_raw-c06
        purchasing_group   = ls_raw-c07
        purchasing_uom     = ls_raw-c08
        purchase_price     = ls_raw-c09
        currency           = ls_raw-c10
        price_unit         = ls_raw-c11
        valid_from         = ls_raw-c12
        valid_to           = ls_raw-c13
        condition_type     = ls_raw-c14
        mrp                = ls_raw-c15
        tot_percent        = ls_raw-c16
        minimum_qty        = ls_raw-c17
        standard_order_qty = ls_raw-c18
        lead_time          = ls_raw-c19
        supplier_material  = ls_raw-c20

      ).

      "Validate mandatory and optional fields
      check_row(
        CHANGING
          cs_row = ls_row
      ).

      "Keep every record, including ERROR rows
      APPEND ls_row TO et_rows.

    ENDLOOP.

    IF et_rows IS INITIAL.
      ev_error = 'No data records found'.
    ENDIF.

  ENDMETHOD.


  METHOD check_row.

    "==========================================
    "1. Initial status
    "==========================================

    CLEAR cs_row-message_text.

    cs_row-process_status = 'UPLOADED'.

    cs_row-upload_action =
      to_upper(
        condense( cs_row-upload_action )
      ).

    cs_row-supplier =
      condense( cs_row-supplier ).

    cs_row-material =
      condense( cs_row-material ).

    cs_row-plant =
      to_upper(
        condense( cs_row-plant )
      ).

    cs_row-purchasing_uom =
      to_upper(
        condense( cs_row-purchasing_uom )
      ).

    cs_row-currency =
      to_upper(
        condense( cs_row-currency )
      ).

    cs_row-condition_type =
      to_upper(
        condense( cs_row-condition_type )
      ).

    "==========================================
    "2. Mandatory field validation
    "==========================================

    IF cs_row-upload_action <> 'CREATE'
       AND cs_row-upload_action <> 'UPDATE'.

      cs_row-message_text =
        'Action must be CREATE or UPDATE'.

    ELSEIF cs_row-supplier IS INITIAL.

      cs_row-message_text =
        'Supplier not maintained'.

    ELSEIF cs_row-material IS INITIAL.

      cs_row-message_text =
        'Article/Material not maintained'.

    ELSEIF cs_row-plant IS INITIAL.

      cs_row-message_text =
        'DC/Plant not maintained'.

    ELSEIF cs_row-purchasing_uom IS INITIAL.

      cs_row-message_text =
        'Purchasing UoM not maintained'.

    ELSEIF cs_row-purchase_price IS INITIAL.

      cs_row-message_text =
        'Purchase Price not maintained'.

    ELSEIF cs_row-currency IS INITIAL.

      cs_row-message_text =
        'Currency not maintained'.

    ELSEIF cs_row-price_unit IS INITIAL.

      cs_row-message_text =
        'Price Unit not maintained'.

    ELSEIF cs_row-valid_from IS INITIAL.

      cs_row-message_text =
        'Valid From not maintained'.

    ELSEIF cs_row-mrp IS INITIAL.

      cs_row-message_text =
        'MRP not maintained'.

    ELSEIF cs_row-tot_percent IS INITIAL.

      cs_row-message_text =
        'TOT Percent not maintained'.

    ENDIF.

    "==========================================
    "3. Mandatory numeric validation
    "==========================================

    IF cs_row-message_text IS INITIAL.

      IF NOT matches(
        val = cs_row-purchase_price
        regex = '^[0-9]{1,13}([.][0-9]{1,2})?$'
      ).

        cs_row-message_text =
          'Invalid Purchase Price'.

      ELSEIF NOT matches(
        val = cs_row-price_unit
        regex = '^[1-9][0-9]{0,4}$'
      ).

        cs_row-message_text =
          'Invalid Price Unit'.

      ELSEIF NOT matches(
        val = cs_row-mrp
        regex = '^[0-9]{1,13}([.][0-9]{1,2})?$'
      ).

        cs_row-message_text =
          'Invalid MRP'.

      ELSEIF NOT matches(
        val = cs_row-tot_percent
        regex = '^[0-9]{1,5}([.][0-9]{1,2})?$'
      ).

        cs_row-message_text =
          'Invalid TOT Percent'.

      ENDIF.

    ENDIF.

    "==========================================
    "4. Mandatory Valid From
    "==========================================

    IF cs_row-message_text IS INITIAL.

      IF NOT matches(
        val = cs_row-valid_from
        regex = '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      ).

        cs_row-message_text =
          'Invalid Valid From (YYYY-MM-DD)'.

      ENDIF.

    ENDIF.

    "==========================================
    "5. Optional Valid To
    "==========================================

    IF cs_row-message_text IS INITIAL
       AND cs_row-valid_to IS NOT INITIAL.

      IF NOT matches(
        val = cs_row-valid_to
        regex = '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      ).

        cs_row-message_text =
          'Invalid Valid To (YYYY-MM-DD)'.

      ELSEIF cs_row-valid_to <
             cs_row-valid_from.

        cs_row-message_text =
          'Valid To before Valid From'.

      ENDIF.

    ENDIF.

    "==========================================
    "6. Optional MOQ
    "==========================================

    IF cs_row-message_text IS INITIAL
       AND cs_row-minimum_qty IS NOT INITIAL.

      IF NOT matches(
        val = cs_row-minimum_qty
        regex = '^[0-9]{1,10}([.][0-9]{1,3})?$'
      ).

        cs_row-message_text =
          'Invalid MOQ'.

      ENDIF.

    ENDIF.

    "==========================================
    "7. Optional Standard Order Quantity
    "==========================================

    IF cs_row-message_text IS INITIAL
       AND cs_row-standard_order_qty IS NOT INITIAL.

      IF NOT matches(
        val = cs_row-standard_order_qty
        regex = '^[0-9]{1,10}([.][0-9]{1,3})?$'
      ).

        cs_row-message_text =
          'Invalid Standard Order Qty'.

      ENDIF.

    ENDIF.

    "==========================================
    "8. Optional Lead Time
    "==========================================

    IF cs_row-message_text IS INITIAL
       AND cs_row-lead_time IS NOT INITIAL.

      IF NOT matches(
        val = cs_row-lead_time
        regex = '^[0-9]{1,9}$'
      ).

        cs_row-message_text =
          'Invalid Lead Time'.

      ENDIF.

    ENDIF.

    "==========================================
    "9. Final row status
    "==========================================

    IF cs_row-message_text IS NOT INITIAL.

      cs_row-process_status = 'ERROR'.

    ELSE.

      cs_row-process_status = 'UPLOADED'.

      cs_row-message_text =
        'Excel row uploaded successfully'.

    ENDIF.

  ENDMETHOD.

ENDCLASS.

