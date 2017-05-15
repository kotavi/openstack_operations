import argparse
from PyPDF2 import PdfFileMerger


parser = argparse.ArgumentParser()
parser.add_argument('--files_list', help='list of pdf files', nargs='+')
parser.add_argument('--output', help='path to the combined pdf file')

args = parser.parse_args()

list_of_pdf_files = args.files_list
output_file = args.output

pdfs = list_of_pdf_files
merger = PdfFileMerger()
for pdf in pdfs:
    merger.append(open(pdf, 'rb'))
with open(output_file, 'wb') as fout:
    merger.write(fout)




