@EndUserText.label: 'Sales Order Item - UI'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZSIM_C_SALESORDERITEM
  as projection on ZSIM_I_SALESORDERITEM
{
  key OrderId,
  key ItemNumber,
      ProductId,
      PlantId,
      Quantity,

      @Semantics.amount.currencyCode: 'Currency'
      NetAmount,
      Currency,

      /* Associations */
      _SalesOrder : redirected to parent ZSIM_C_SALESORDER,
      _Product    : redirected to ZSIM_C_PRODUCT
}
