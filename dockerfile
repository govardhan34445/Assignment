FROM perl:latest
RUN wget  http://cpanmin.us | perl - --sudo Dancer2
RUN cpan install Dancer2
RUN cpan install cpan IPC::Run
RUN cpan install File::RotateLogs 
RUN cpan install WWW::Mechanize
RUN cpan install Test::Output
RUN cpan install LWP::ConsoleLogger::Everywhere
RUN cpan install Dancer2::Logger::File::RotateLogs
RUN cpan install DBD::SQLite
RUN cpan install Starman
RUN cpan install YAML
RUN cpan install URL::Encode::XS
RUN cpan install CGI::Deurl::XS
RUN cpan install HTTP::Parser::XS
RUN cpan install Crypt::SaltedHash
RUN git clone gitswarm.f5net.com:rakeshgroup/soc-ui-live.git 
EXPOSE 9090
WORKDIR Dancer/CMAdmin
CMD starman --port 9090 bin/app.psgi
