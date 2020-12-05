requires "Dancer2" => "0.300000";
requires "IPC::Run" => "20180523.0";
requires "WWW::Mechanize" => "1.95";
requires "LWP::ConsoleLogger::Everywhere" => "0.000042";
requires "Dancer2::Logger::File::RotateLogs" => "0.01";
requires "DBD::SQLite" => "1.64";
requires "Starman" => "0";

recommends "YAML"             => "0";
recommends "URL::Encode::XS"  => "0";
recommends "CGI::Deurl::XS"   => "0";
recommends "HTTP::Parser::XS" => "0";

on "test" => sub {
    requires "Test::More"            => "0";
    requires "HTTP::Request::Common" => "0";
};

