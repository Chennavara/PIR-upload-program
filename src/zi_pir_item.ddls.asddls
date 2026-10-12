
@EndUserText.label: 'PIR Upload Item Interface'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define view entity ZI_PIR_ITEM
  as select from zpir_up_i

  association to parent ZI_PIR_UPLOAD as _Upload
    on $projection.UploadUUID = _Upload.UploadUUID

{
  key item_uuid as ItemUUID,

      upload_uuid as UploadUUID,
      row_no as RowNo,

      upload_action as UploadAction,

      supplier as Supplier,
      material as Material,
      material_group as MaterialGroup,

      purchasing_org as PurchasingOrg,
      plant as Plant,
      purchasing_group as PurchasingGroup,

      //@Semantics.unitOfMeasure: true
      purchasing_uom as PurchasingUoM,

      currency as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      purchase_price as PurchasePrice,

      price_unit as PriceUnit,

      valid_from as ValidFrom,
      valid_to as ValidTo,

      condition_type as ConditionType,

      @Semantics.amount.currencyCode: 'Currency'
      mrp as MRP,

      tot_percent as TOTPercent,

      @Semantics.quantity.unitOfMeasure: 'PurchasingUoM'
      minimum_qty as MinimumQty,

      @Semantics.quantity.unitOfMeasure: 'PurchasingUoM'
      standard_order_qty as StandardOrderQty,

      lead_time as LeadTime,
      supplier_material as SupplierMaterial,

      info_record as InfoRecord,
      process_status as ProcessStatus,
      message_text as MessageText,

      _Upload
}
