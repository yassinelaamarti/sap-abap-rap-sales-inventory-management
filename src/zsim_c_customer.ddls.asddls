@EndUserText.label: 'Customer - UI'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define root view entity ZSIM_C_CUSTOMER
  as projection on ZSIM_I_CUSTOMER
{
  key CustomerId,
      CustomerName,
      City,
      CountryCode
}
