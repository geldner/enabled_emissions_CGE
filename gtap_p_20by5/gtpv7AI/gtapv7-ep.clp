! closure for ALTERTAX simulation
Exogenous ! Part of closure for altertax runs
          pop
          psaveslack pfactwld
          profitslack incomeslack endwslack
!          cgdslack 
          tradslack
          ams atm atf ats atd
          aosec aoreg 
          afcom afsec afreg afecom afesec afereg
          aoall afall afeall
          au dppriv dpgov dpsave
          to tinc 
          tpreg tm tms tx txs
          qe
          qesf
! Additional exogenous variables for GTAP-E
          del_ctgshr del_rctaxb pemp
  
!    del_tbalry exogenous for all regions except one,
!    and CGDSLACK exogenous for that one region (which can be any one).