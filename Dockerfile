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
    cron \
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

# copy crontab file into the container
COPY crontab /etc/cron.d/crontab

# set permissions for the crontab file
RUN chmod 0644 /etc/cron.d/crontab

# Apply cron job
RUN crontab /etc/cron.d/crontab

# Set permissions for the CGI scripts to be executable
RUN chmod -R 755 /usr/local/apache2/cgi-bin

# Set permissions for outputs and stat 
RUN chmod -R 777 /usr/local/apache2/htdocs/outputs
RUN chmod 777 /usr/local/apache2/htdocs/stats/integrationsites.stat

# Enable CGI module in Apache
RUN echo "LoadModule cgi_module modules/mod_cgi.so" >> /usr/local/apache2/conf/httpd.conf && \
    echo "AddHandler cgi-script .cgi .pl" >> /usr/local/apache2/conf/httpd.conf && \
    sed -i 's/DirectoryIndex index.html/DirectoryIndex index.html index.cgi/' /usr/local/apache2/conf/httpd.conf && \
    sed -i '/<Directory "\/usr\/local\/apache2\/htdocs">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /usr/local/apache2/conf/httpd.conf && \
    sed -i '/<Directory "\/usr\/local\/apache2\/cgi-bin">/,/<\/Directory>/ s/Options None/Options +ExecCGI/' /usr/local/apache2/conf/httpd.conf

# Set BLAST version (update this to the latest version as needed)
ENV BLAST_VERSION=2.17.0

# Download and install BLAST+
RUN wget https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/${BLAST_VERSION}/ncbi-blast-${BLAST_VERSION}+-x64-linux.tar.gz && \
    tar -xzf ncbi-blast-${BLAST_VERSION}+-x64-linux.tar.gz && \
    mv ncbi-blast-${BLAST_VERSION}+ ncbi-blast && \
    rm ncbi-blast-${BLAST_VERSION}+-x64-linux.tar.gz

# makeblastdb for HXB2
WORKDIR /usr/local/apache2/htdocs/HXB2
RUN /usr/local/apache2/htdocs/ncbi-blast/bin/makeblastdb -in HXB2.fasta -dbtype nucl

# install NCBI's human genome GRCh38
WORKDIR /usr/local/apache2/htdocs/human_genome/GRCh38.p14
RUN wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/405/GCF_000001405.40_GRCh38.p14/GCF_000001405.40_GRCh38.p14_genomic.gff.gz && \
    gunzip GCF_000001405.40_GRCh38.p14_genomic.gff.gz && \
    python3 /usr/local/apache2/cgi-bin/extractGenesFromGffFile.py GCF_000001405.40_GRCh38.p14_genomic.gff GRCh38.p14_gene.gff && \
    rm GCF_000001405.40_GRCh38.p14_genomic.gff
RUN wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/405/GCF_000001405.40_GRCh38.p14/GCF_000001405.40_GRCh38.p14_genomic.fna.gz && \
    gunzip GCF_000001405.40_GRCh38.p14_genomic.fna.gz && \
    mv GCF_000001405.40_GRCh38.p14_genomic.fna GRCh38.p14_genomic.fna && \
    /usr/local/apache2/htdocs/ncbi-blast/bin/makeblastdb -in GRCh38.p14_genomic.fna -dbtype nucl && \
    rm GRCh38.p14_genomic.fna

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

# install NCBI's human genome T2T-CHM13v2.0
WORKDIR /usr/local/apache2/htdocs/human_genome/T2T-CHM13v2.0
RUN wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/009/914/755/GCF_009914755.1_T2T-CHM13v2.0/GCF_009914755.1_T2T-CHM13v2.0_genomic.gff.gz && \
    gunzip GCF_009914755.1_T2T-CHM13v2.0_genomic.gff.gz && \
    python3 /usr/local/apache2/cgi-bin/extractGenesFromGffFile.py GCF_009914755.1_T2T-CHM13v2.0_genomic.gff T2T-CHM13v2.0_gene.gff && \
    rm GCF_009914755.1_T2T-CHM13v2.0_genomic.gff
RUN wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/009/914/755/GCF_009914755.1_T2T-CHM13v2.0/GCF_009914755.1_T2T-CHM13v2.0_genomic.fna.gz && \
    gunzip GCF_009914755.1_T2T-CHM13v2.0_genomic.fna.gz && \
    mv GCF_009914755.1_T2T-CHM13v2.0_genomic.fna T2T-CHM13v2.0_genomic.fna && \
    /usr/local/apache2/htdocs/ncbi-blast/bin/makeblastdb -in T2T-CHM13v2.0_genomic.fna -dbtype nucl && \
    rm T2T-CHM13v2.0_genomic.fna

# Expose port 80 for HTTP traffic
EXPOSE 80

# Start Apache in the foreground and enable cron service
CMD service cron start && httpd -D FOREGROUND
