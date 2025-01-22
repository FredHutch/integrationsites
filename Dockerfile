# Step 1: Use the official Apache HTTPD image
FROM httpd:2.4

# Set environment variables
#ENV DEBIAN_FRONTEND = noninteractive

# Step 2: Install Perl and mod_cgi to enable Perl CGI
RUN apt-get update && apt-get install -y \
    perl \
    libapache2-mod-perl2 \
    build-essential \
    cpanminus \
    && rm -rf /var/lib/apt/lists/*

# Step 2: Install cpanm (if not already installed)
#RUN cpan App::cpanminus

# Step 3: Enable mod_cgi to process Perl scripts
#RUN a2enmod cgi
#RUN cpanm CGI
RUN cpanm CGI Email::Simple Email::Sender::Simple Email::Sender::Transport::SMTP

# Step 3: Copy your Perl CGI scripts into the container
COPY ./cgi-bin /usr/local/apache2/cgi-bin

# Step 4: Copy your CSS files and other static assets into the container
#COPY ./stylesheets /usr/local/apache2/htdocs/static
#COPY ./javascripts /usr/local/apache2/htdocs/static

# Step 5: Copy your files into the container
COPY ./htdocs /usr/local/apache2/htdocs

# Step 6: Copy your other stuff into the container
#COPY ./ncbi-blast /usr/local/apache2/htdocs/blast
#COPY ./human_genome /usr/local/apache2/htdocs/human_genome
COPY Dockerfile /usr/local/apache2

# Step 6: Set permissions for the CGI scripts to be executable
RUN chmod -R 755 /usr/local/apache2/cgi-bin

# Enable CGI module in Apache
RUN echo "LoadModule cgi_module modules/mod_cgi.so" >> /usr/local/apache2/conf/httpd.conf && \
    echo "AddHandler cgi-script .cgi .pl" >> /usr/local/apache2/conf/httpd.conf && \
    sed -i 's/DirectoryIndex index.html/DirectoryIndex index.html index.cgi/' /usr/local/apache2/conf/httpd.conf && \
    sed -i '/<Directory "\/usr\/local\/apache2\/htdocs">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /usr/local/apache2/conf/httpd.conf && \
    sed -i '/<Directory "\/usr\/local\/apache2\/cgi-bin">/,/<\/Directory>/ s/Options None/Options +ExecCGI/' /usr/local/apache2/conf/httpd.conf

# Step 8: Expose port 80 for HTTP traffic
EXPOSE 80

# Step 9: Start Apache in the foreground
CMD ["httpd-foreground"]
