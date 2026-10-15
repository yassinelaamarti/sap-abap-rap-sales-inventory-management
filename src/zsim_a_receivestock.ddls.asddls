@EndUserText.label: 'Receive Stock - Parameters'
define abstract entity ZSIM_A_RECEIVESTOCK
{
  @EndUserText.label: 'Quantity received'
  Quantity  : abap.dec( 13, 3 );

  @EndUserText.label: 'Reference (delivery note, PO)'
  Reference : abap.char( 40 );
}
