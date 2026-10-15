@EndUserText.label: 'Sales Order - UI'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define root view entity ZSIM_C_SALESORDER
  provider contract transactional_query
  as projection on ZSIM_I_SALESORDER
{
  key OrderId,
      CustomerId,
      PlantId,
      OrderDate,
      Status,

      @Semantics.amount.currencyCode: 'Currency'
      TotalAmount,
      Currency,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SIM_ORDER_STATUS_CALC'
      virtual StatusText        : abap.char( 20 ),

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SIM_ORDER_STATUS_CALC'
      virtual StatusCriticality : abap.int1,

      LocalLastChangedAt,
      LastChangedAt,

      /* Associations */
      _Customer : redirected to ZSIM_C_CUSTOMER,
      _Plant,
      _Items : redirected to composition child ZSIM_C_SALESORDERITEM
}
