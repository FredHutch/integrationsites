# Use the official Apache HTTPD image
FROM httpd:2.4

# Install Perl and mod_cgi to enable Perl CGI, and other stuff
RUN apt-get update && apt-get install -y \
    perl \
    python3 \
    libapache2-mod-perl2 \
    build-essential \
    cpanminus \
    wget \
    tar \
    && rm -rf /var/lib/apt/lists/*

# Enable mod_cgi to process Perl scripts
#RUN a2enmod cgi
#RUN cpanm CGI
RUN cpanm CGI Email::Simple Email::Sender::Simple Email::Sender::Transport::SMTP

# Copy Perl CGI scripts into the container
COPY ./cgi-bin /usr/local/apache2/cgi-bin

# Copy htdocs files into the container
COPY ./htdocs /usr/local/apache2/htdocs

# Copy Dockerfile into the container
COPY Dockerfile /usr/local/apache2

# Set permissions for the CGI scripts to be executable
RUN chmod -R 755 /usr/local/apache2/cgi-bin

# Enable CGI module in Apache
RUN echo "LoadModule cgi_module modules/mod_cgi.so" >> /usr/local/apache2/conf/httpd.conf && \
    echo "AddHandler cgi-script .cgi .pl" >> /usr/local/apache2/conf/httpd.conf && \
    sed -i 's/DirectoryIndex index.html/DirectoryIndex index.html index.cgi/' /usr/local/apache2/conf/httpd.conf && \
    sed -i '/<Directory "\/usr\/local\/apache2\/htdocs">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /usr/local/apache2/conf/httpd.conf && \
    sed -i '/<Directory "\/usr\/local\/apache2\/cgi-bin">/,/<\/Directory>/ s/Options None/Options +ExecCGI/' /usr/local/apache2/conf/httpd.conf

# install NCBI's blast executables
WORKDIR /usr/local/apache2/htdocs
RUN wget https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-2.16.0+-x64-linux.tar.gz && \
    tar -xzf ncbi-blast-2.16.0+-x64-linux.tar.gz && \
    mv ncbi-blast-2.16.0+ ncbi-blast && \
    rm ncbi-blast-2.16.0+-x64-linux.tar.gz

# makeblastdb for HXB2
WORKDIR /usr/local/apache2/htdocs/HXB2
RUN /usr/local/apache2/htdocs/ncbi-blast/bin/makeblastdb -in HXB2.fasta -dbtype nucl

# install NCBI's human genome GRCh38
WORKDIR /usr/local/apache2/htdocs/human_genome/GRCh38.p2
RUN wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/405/GCF_000001405.28_GRCh38.p2/GCF_000001405.28_GRCh38.p2_genomic.gff.gz && \
    gunzip GCF_000001405.28_GRCh38.p2_genomic.gff.gz && \
    python3 /usr/local/apache2/cgi-bin/extractGenesFromGffFile.py GCF_000001405.28_GRCh38.p2_genomic.gff GRCh38.p2_gene.gff && \
    rm GCF_000001405.28_GRCh38.p2_genomic.gff
RUN wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/405/GCF_000001405.28_GRCh38.p2/GCF_000001405.28_GRCh38.p2_genomic.fna.gz && \
    gunzip GCF_000001405.28_GRCh38.p2_genomic.fna.gz && \
    mv GCF_000001405.28_GRCh38.p2_genomic.fna GRCh38.p2_genomic.fna && \
    /usr/local/apache2/htdocs/ncbi-blast/bin/makeblastdb -in GRCh38.p2_genomic.fna -dbtype nucl && \
    rm GRCh38.p2_genomic.fna

# install NCBI's human genome GRCh37
WORKDIR /usr/local/apache2/htdocs/human_genome/GRCh37.p13
RUN wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/405/GCF_000001405.25_GRCh37.p13/GCF_000001405.25_GRCh37.p13_genomic.gff.gz && \
    gunzip GCF_000001405.25_GRCh37.p13_genomic.gff.gz && \
    python3 /usr/local/apache2/cgi-bin/extractGenesFromGffFile.py GCF_000001405.25_GRCh37.p13_genomic.gff GRCh37.p13_gene.gff && \
    rm GCF_000001405.25_GRCh37.p13_genomic.gff
RUN wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/405/GCF_000001405.25_GRCh37.p13/GCF_000001405.25_GRCh37.p13_genomic.fna.gz && \
    gunzip GCF_000001405.25_GRCh37.p13_genomic.fna.gz && \
    mv GCF_000001405.25_GRCh37.p13_genomic.fna GRCh37.p13_genomic.fna && \
    /usr/local/apache2/htdocs/ncbi-blast/bin/makeblastdb -in GRCh37.p13_genomic.fna -dbtype nucl && \
    rm GRCh37.p13_genomic.fna

# Expose port 80 for HTTP traffic
EXPOSE 80

# Start Apache in the foreground
CMD ["httpd-foreground"]
