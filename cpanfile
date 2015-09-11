requires "Carp" => "0";
requires "DBI" => "0";
requires "Exporter" => "0";
requires "List::MoreUtils" => "0";
requires "MRO::Compat" => "0";
requires "Params::Callbacks" => "0";
requires "Scalar::Util" => "0";
requires "Sub::Install" => "0";
requires "namespace::clean" => "0";
requires "strict" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "Data::Dumper" => "0";
  requires "JSON" => "0";
  requires "Test::More" => "0";
  requires "perl" => "5.006";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
};
