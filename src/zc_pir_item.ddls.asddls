
@EndUserText.label: 'PIR Upload Item Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true

define view entity ZC_PIR_ITEM
  as projection on ZI_PIR_ITEM
{
  key ItemUUID,

      UploadUUID,
      RowNo,
      UploadAction,

      Supplier,
      Material,
      MaterialGroup,

      PurchasingOrg,
      Plant,
      PurchasingGroup,

      PurchasingUoM,

      @Semantics.amount.currencyCode: 'Currency'
      PurchasePrice,

      Currency,
      PriceUnit,

      ValidFrom,
      ValidTo,

      ConditionType,

      @Semantics.amount.currencyCode: 'Currency'
      MRP,

      TOTPercent,

      @Semantics.quantity.unitOfMeasure: 'PurchasingUoM'
      MinimumQty,

      @Semantics.quantity.unitOfMeasure: 'PurchasingUoM'
      StandardOrderQty,

      LeadTime,
      SupplierMaterial,

      InfoRecord,
      ProcessStatus,
      MessageText,

      _Upload : redirected to parent ZC_PIR_UPLOAD
}
