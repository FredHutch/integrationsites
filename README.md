# Integration Sites

[IntegrationSites](https://integrationsites.fredhutch.org) is a Bioinformatics tool used to detect the integration sites of HIV into the human genome.

## Usage

After user uploads a FASTA file with the query sequences, the program performs a BLAST search against the human genome (GRCh38.p14, T2T-CHM13v2.0 or GRCh37.p13 reference assembly) 
and outputs the information shown in the example output below. If a sequence is not found in the human genome, the program will then BLAST against the HIV HXB2 sequence. 
If "Trim LTR sequence first" is checked, the program will look for the sequence of "TCTCTAGCA", a conserved sequence at the 3' end of the LTR, and trim it along with the adjacent viral sequence 
if the 3'LTR is selected, or the sequence of "GCCCTTCCA" and the adjacent viral sequence will be trimmed if the 5'LTR is selected. For the details how to prepare sequences and run the tool, 
please read the instruction [PDF](https://integrationsites.fredhutch.org/docs/IS_tool_instructions.pdf) here.

## Contact

For any questions, bugs and suggestions, please send email to cohnlabsupport@fredhutch.org and include a few sentences describing, briefly, the nature of your questions and include contact information.
