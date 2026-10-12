
@EndUserText.label: 'PIR Upload Header Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: false

define root view entity ZC_PIR_UPLOAD
  provider contract transactional_query
  as projection on ZI_PIR_UPLOAD
{
  key UploadUUID,

      FileName,
      MimeType,
      FileContent,

      UploadStatus,

      TotalRecords,
      SuccessRecords,
      ErrorRecords,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Items : redirected to composition child ZC_PIR_ITEM
}
