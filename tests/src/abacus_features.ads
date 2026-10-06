with Fabula.Main;

with Abacus_Steps;

--  The feature runner: Fabula.Main over the crate's step registry,
--  run over tests/features/ by `make features` and `alr test`.

procedure Abacus_Features is new
  Fabula.Main
    (Steps     => Abacus_Steps.Steps,
     Step_Defs => Abacus_Steps.Step_Defs,
     Hook_Defs => Abacus_Steps.Hook_Defs,
     Execute   => Abacus_Steps.Execute,
     Run_Hook  => Abacus_Steps.Run_Hook);
