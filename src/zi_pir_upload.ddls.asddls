
@EndUserText.label: 'PIR Upload Header Interface'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define root view entity ZI_PIR_UPLOAD
  as select from zpir_up_h

  composition [0..*] of ZI_PIR_ITEM as _Items

{
  key upload_uuid as UploadUUID,

      file_name as FileName,

      @Semantics.mimeType: true
      mime_type as MimeType,

      @Semantics.largeObject: {
        mimeType: 'MimeType',
        fileName: 'FileName',
        acceptableMimeTypes: [
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        ],
        contentDispositionPreference: #ATTACHMENT
      }
      file_content as FileContent,

      upload_status as UploadStatus,

      total_records as TotalRecords,
      success_records as SuccessRecords,
      error_records as ErrorRecords,

      @Semantics.user.createdBy: true
      created_by as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at as CreatedAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at as LastChangedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Items
}
