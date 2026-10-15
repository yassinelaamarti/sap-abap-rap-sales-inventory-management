@EndUserText.label: 'Product Catalog - UI'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define root view entity ZSIM_C_PRODUCT
  provider contract transactional_query
  as projection on ZSIM_I_PRODUCT
{
  key ProductId,
      ProductName,
      UnitPrice,
      Currency,
      ReorderThreshold,

      /* Associations */
      _Stock : redirected to composition child ZSIM_C_STOCK
}
