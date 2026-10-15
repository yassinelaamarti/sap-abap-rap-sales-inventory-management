CLASS zcl_sim_test_eml DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_sim_test_eml IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    " Test 1 : création valide (attendu : failed = 0, commande SO-0003)
    MODIFY ENTITIES OF zsim_i_salesorder
      ENTITY SalesOrder
        CREATE FIELDS ( CustomerId PlantId OrderDate )
        WITH VALUE #( ( %cid = 'O1' CustomerId = 'C-0003' PlantId = '1000'
                        OrderDate = cl_abap_context_info=>get_system_date( ) ) )
        CREATE BY \_Items FIELDS ( ProductId Quantity )
        WITH VALUE #( ( %cid_ref = 'O1'
                        %target = VALUE #( ( %cid = 'I1' ProductId = 'P-0002' Quantity = 4 ) ) ) )
      MAPPED DATA(mapped1) FAILED DATA(failed1) REPORTED DATA(reported1).
    COMMIT ENTITIES RESPONSE OF zsim_i_salesorder
      FAILED DATA(commit_failed1) REPORTED DATA(commit_reported1).
    out->write( |Test 1 - failed: { lines( failed1-salesorder ) + lines( commit_failed1-salesorder ) }| ).
    IF mapped1-salesorder IS NOT INITIAL.
      out->write( |Test 1 - OrderId cree: { mapped1-salesorder[ 1 ]-OrderId }| ).
    ENDIF.
    ROLLBACK ENTITIES.

    " Test 2 : date future (attendu : failed = 1)
    MODIFY ENTITIES OF zsim_i_salesorder
      ENTITY SalesOrder
        CREATE FIELDS ( CustomerId PlantId OrderDate )
        WITH VALUE #( ( %cid = 'O2' CustomerId = 'C-0001' PlantId = '1000'
                        OrderDate = cl_abap_context_info=>get_system_date( ) + 10 ) )
      MAPPED DATA(mapped2) FAILED DATA(failed2) REPORTED DATA(reported2).
    COMMIT ENTITIES RESPONSE OF zsim_i_salesorder
      FAILED DATA(commit_failed2) REPORTED DATA(commit_reported2).
    out->write( |Test 2 - failed: { lines( failed2-salesorder ) + lines( commit_failed2-salesorder ) }| ).
    ROLLBACK ENTITIES.

    " Test 3 : quantité = 0 (attendu : failed = 1)
    MODIFY ENTITIES OF zsim_i_salesorder
      ENTITY SalesOrder
        CREATE FIELDS ( CustomerId PlantId OrderDate )
        WITH VALUE #( ( %cid = 'O3' CustomerId = 'C-0001' PlantId = '1000'
                        OrderDate = cl_abap_context_info=>get_system_date( ) ) )
        CREATE BY \_Items FIELDS ( ProductId Quantity )
        WITH VALUE #( ( %cid_ref = 'O3'
                        %target = VALUE #( ( %cid = 'I3' ProductId = 'P-0002' Quantity = 0 ) ) ) )
      MAPPED DATA(mapped3) FAILED DATA(failed3) REPORTED DATA(reported3).
    COMMIT ENTITIES RESPONSE OF zsim_i_salesorder
      FAILED DATA(commit_failed3) REPORTED DATA(commit_reported3).
    out->write( |Test 3 - failed: { lines( failed3-salesorderitem ) + lines( commit_failed3-salesorderitem ) }| ).
    ROLLBACK ENTITIES.

  ENDMETHOD.
ENDCLASS.
