#!/usr/bin/python

import json
import random
import string
import os.path
import logging
from xml.dom import minidom

from bs4 import BeautifulSoup
from ConfigParser import SafeConfigParser

html_report = open('templates/main_template.html', 'r+')
soup = BeautifulSoup(html_report, 'html.parser')

parser = SafeConfigParser()
parser.optionxform = str  # is used to preserve keys with capital letters read from a config-file
parser.read('config.ini')

def _gen_random_str(length):
    return ''.join(random.choice(string.lowercase) for i in range(length))


def check_section(section, key_list, message):
    def decorator(function):
        def wrapper():
            try:
                for key in key_list:
                    parser.has_option(section, key)
                function()
            except:
                logging.warning(message)
        return wrapper
    return decorator


@check_section('TitlePage', ['CustomerName', 'ProjectName', 'Version', 'Date'], 'Check section "TitlePage"')
def _project_data():
    """
    Insert data from 'TitlePage' section into html template
    """
    customer_name = soup.find('p', attrs={'id': 'customer_name'})
    customer_name.string = parser.get('TitlePage', 'CustomerName')
    project_name = soup.find('p', attrs={'id': 'project_name'})
    project_name.string = parser.get('TitlePage', 'ProjectName')
    version = soup.find('p', attrs={'id': 'document_version'})
    version.string = parser.get('TitlePage', 'Version')
    date = soup.find('p', attrs={'id': 'date'})
    date.string = parser.get('TitlePage', 'Date')


@check_section('TitlePage', ['Authors'], 'Check list of authors')
def _authors():
    """
    Insert data about authors from 'TitlePage' section into html template
    """
    list_authors = parser.get('TitlePage', 'Authors').split('\n')
    authors = soup.find('p', attrs={'id': 'authors'})
    blockquote_id = _gen_random_str(9)
    authors.append(soup.new_tag('blockquote', **{'class': 'c2', 'id': blockquote_id}))
    tag_blockquote = authors.find('blockquote', attrs={'id': blockquote_id})
    for author in list_authors:
        tag_blockquote.append(author)
        tag_blockquote.append(soup.new_tag('br'))


def title_page():
    """
    Propagate data from config file to the title page
    """
    _project_data()
    _authors()


@check_section('Conclusion', ['Result'], 'Section "Conclusion" '
                                         'should have key "Result" with "READY/NOT READY" value')
def _result_of_validation():
    """
    Finds tag 'span' with text 'RESULT' in html template document and
    depending on value of 'Result' in config file changes text
    to 'READY' or 'NOT READY' and its color:
    'READY' - green
    'NOT READY' - red
    """
    for i in soup.findAll('span', text='RESULT'):
        if i.string == "RESULT" and parser.get('Conclusion', 'Result') == 'READY':
            i.string = 'READY'
            soup.find('span', attrs={'id': 'verification_result'})['style'] = 'color: green'
        else:
            i.string = 'NOT READY'
            soup.find('span', attrs={'id': 'verification_result'})['style'] = 'color: red'


def _insert_list(ul_id, section, key):
    """
    Paste a list to the html template
    :param ul_id: id of tag 'ul'
    :param section: section name from config file
    :param key: key name from section

    """
    ul_tag = soup.find('ul', attrs={'id': ul_id})
    executed_tests = parser.get(section, key).split('\n')
    for text in executed_tests:
        li_id = 'li_' + _gen_random_str(10)
        ul_tag.append(soup.new_tag('li', **{'id': li_id}))
        tag_li = ul_tag.find('li', attrs={'id': li_id})
        tag_li.append(text)


def _paste_text(section, option, tag_p_id):
    """
    Insert text from specified section key
    """
    text_to_paste = parser.get(section, option).split('\n')
    p_tag = soup.find('p', attrs={'id': tag_p_id})
    for text in text_to_paste:
        p_tag.string = text
        p_tag.append(soup.new_tag('br'))
        p_tag.append(soup.new_tag('br'))


@check_section('Conclusion', ['ExecutedTests'], 'Check section "Conclusion" key "ExecutedTests"')
def conclusion():
    """
    Fills in conclusion section with content from config file

    """
    # insert result of validation
    _result_of_validation()

    # insert list of executed tests
    _insert_list('executed_tests', 'Conclusion', 'ExecutedTests')

    # insert text for conclusion part
    _paste_text('Conclusion', 'ConclusionText', 'conclusion_text')


def insert_date_and_author(tag, attr, test, id_owner, id_date):
    """
    Insert information about person who was responsible
    for the testing procedure of this particular test suite

    :param tag: html tag used for place identification inside html document
    :param attr: html attribute used for place identification inside html document
    :param test: name of the test, should be the same as in config.ini
    :param id_owner:  html id used for place identification inside html document
    :param id_date:  html id used for place identification inside html document

    """
    try:
        owner = soup.find(tag, attrs={attr: id_owner})
        owner.string = parser.get(test, 'TestOwner')
        date = soup.find(tag, attrs={attr: id_date})
        date.string = parser.get(test, 'TestDate')
        date.append(soup.new_tag('br'))
        date.append(soup.new_tag('br'))
    except:
        logging.warning('Check "TestOwner" and "TestDate" for section %s' % test)


def append_td(i, k, tag_tr, td_id, percent):
    if str(i) == k:
        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                            'style': 'width:%s; word-break: break-word' % percent}))
    if str(i) == '1':
        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                            'style': 'width:25%; word-break: break-word'}))
    if str(i) == '2':
        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                            'style': 'width:15%; word-break: break-word'}))
    if str(i) == '3':
        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                            'style': 'width:30%; word-break: break-word'}))


def update_table_four_columns(table_id, tbody_id, parser_section):
    """
    Adds rows with 4 columns to the table in section 'New Issues Found' of html template.
    Number of rows depends on number of keys in the section 'Issues'.
    Each column has 'p' tag with appropriate text from config.
    column1     column2     column3     column4
    JIRA link   Severity    Summary     Comments

    """
    table = soup.find("table", attrs={'id': table_id})
    tag_tbody = table.find('tbody', attrs={'id': tbody_id})
    try:
        parser_data = parser.items(parser_section)
        for issue in parser_data:
            tr_id = 'tr_' + _gen_random_str(10)
            tag_tbody.append(soup.new_tag('tr', **{'class': 'c20', 'id': tr_id}))
            tag_tr = table.find('tr', attrs={'id': tr_id})

            td_id = 'td_' + _gen_random_str(10)
            issue_list = issue[1].split('\n')
            if parser_section == 'TestTools':
                for i in range(4):
                    # tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i}))
                    if str(i) == '0':
                        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                            'style': 'width:15%; word-break: break-word'}))
                    if str(i) == '1':
                        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                            'style': 'width:15%; word-break: break-word'}))
                    if str(i) == '2':
                        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                            'style': 'width:25%; word-break: break-word'}))
                    if str(i) == '3':
                        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                            'style': 'width:45%; word-break: break-word'}))
                    tag_td = table.find('td', attrs={'id': td_id + '%s' % i})
                    p_id = 'p_' + _gen_random_str(7)
                    tag_td.append(soup.new_tag('p', **{'class': 'font_style_2', 'id': p_id}))
                    tag_p = table.find('p', attrs={'id': p_id})
                    tag_p.append(issue_list[i])
            if parser_section == 'Issues':
                for i in range(4):
                    if str(i) == '0':
                        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                            'style': 'width:25%; word-break: break-word'}))
                    if str(i) == '1':
                        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                            'style': 'width:15%; word-break: break-word'}))
                    if str(i) == '2':
                        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                            'style': 'width:25%; word-break: break-word'}))
                    if str(i) == '3':
                        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                            'style': 'width:25%; word-break: break-word'}))
                    tag_td = table.find('td', attrs={'id': td_id + '%s' % i})
                    p_id = 'p_' + _gen_random_str(7)
                    tag_td.append(soup.new_tag('p', **{'class': 'font_style_2', 'id': p_id}))
                    tag_p = table.find('p', attrs={'id': p_id})
                    tag_p.append(issue_list[i])
            if parser_section == 'SolutionTestStatus':
                for i in range(4):
                    if str(i) == '0':
                        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                            'style': 'width:25%; word-break: break-word'}))
                    if str(i) == '1':
                        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                            'style': 'width:25%; word-break: break-word'}))
                    if str(i) == '2':
                        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                            'style': 'width:15%; word-break: break-word'}))
                    if str(i) == '3':
                        tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                            'style': 'width:25%; word-break: break-word'}))
                    tag_td = table.find('td', attrs={'id': td_id + '%s' % i})
                    p_id = 'p_' + _gen_random_str(7)
                    tag_td.append(soup.new_tag('p', **{'class': 'font_style_2', 'id': p_id}))
                    tag_p = table.find('p', attrs={'id': p_id})
                    tag_p.append(issue_list[i])
    except:
        logging.warning('Check section %s' % parser_section)


def update_table_two_columns(table_id, tbody_id, parser_section):
    """
    Adds rows with 2 columns to the table.
    Number of rows depends on number of keys in the section.
    Each column has 'p' tag with appropriate text from config.
    column1     column2
    key         value

    :param table_id: id of tag table from html template document
    :param tbody_id: id of tag tbody from html template document
    :param parser_section: name of the section from config file

    """
    table = soup.find("table", attrs={'id': table_id})
    tag_tbody = table.find('tbody', attrs={'id': tbody_id})

    # list_authors = parser.get('TitlePage', 'Authors').split('\n')
    # for author in list_authors:
    #     tag_blockquote.append(author)
    #     tag_blockquote.append(soup.new_tag('br'))

    try:
        parser_data = parser.items(parser_section)
        for line in parser_data:
            # if str(line).find('\\n'):
            #     print line
            tr_id = 'tr_' + _gen_random_str(10)
            tag_tbody.append(soup.new_tag('tr', **{'class': 'c20', 'id': tr_id}))
            tag_tr = table.find('tr', attrs={'id': tr_id})

            td_id = 'td_' + _gen_random_str(10)
            for i in range(2):
                tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i}))
                tag_td = table.find('td', attrs={'id': td_id + '%s' % i})
                tag_td.append(soup.new_tag('p', **{'class': 'font_style_2', 'id': td_id + '%s' % i}))
                tag_p = table.find('p', attrs={'id': td_id + '%s' % i})
                tag_p.append(line[i])
    except:
        logging.warning('Check section %s' % parser_section)


def update_table_three_columns(table_id, tbody_id, parser_section):
    """
    Adds rows with 3 columns to the table.
    Number of rows depends on number of keys in the section.
    Each column has 'p' tag with appropriate text from config.

    :param table_id: id of tag table from html template document
    :param tbody_id: id of tag tbody from html template document
    :param parser_section: name of the section from config file

    """
    table = soup.find("table", attrs={'id': table_id})
    tag_tbody = table.find('tbody', attrs={'id': tbody_id})
    try:
        parser_data = parser.items(parser_section)
        for line in parser_data:
            tr_id = 'tr_' + _gen_random_str(10)
            tag_tbody.append(soup.new_tag('tr', **{'class': 'c20', 'id': tr_id}))
            tag_tr = table.find('tr', attrs={'id': tr_id})
            for i in range(3):
                td_id = 'td_' + _gen_random_str(10)
                # tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i}))
                if str(i) == '0':
                    tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                        'style': 'width:35%%; word-break: break-word'}))
                if str(i) == '1':
                    tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                        'style': 'width:15%; word-break: break-word'}))
                if str(i) == '2':
                    tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                        'style': 'width:50%; word-break: break-word'}))
                tag_td = table.find('td', attrs={'id': td_id + '%s' % i})
                tag_td.append(soup.new_tag('p', **{'class': 'font_style_2', 'id': td_id + '%s' % i}))
                tag_p = table.find('p', attrs={'id': td_id + '%s' % i})
                tag_p.append(line[1].split('\n')[i])
    except:
        logging.warning('Check section %s' % parser_section)


@check_section('Rally', ['Filepath'], 'Check section "Rally" key "Filepath"')
def process_rally_results():
    """
    Fill in result table with Rally test results
    """
    rally_data = parser.get('Rally', 'Filepath')
    if os.path.isfile(rally_data):
        xml_data = minidom.parse(rally_data)
        item_list = xml_data.getElementsByTagName('testsuite')
        errors = item_list[0].attributes['errors'].value
        failures = item_list[0].attributes['failures'].value
        failures = int(errors) + int(failures)
        skipped = 0
        total = item_list[0].attributes['tests'].value
        success = int(total) - int(errors) - int(failures)

        rally_passed = soup.find('p', attrs={'id': 'rally_passed'})
        rally_passed.string = str(success)
        rally_skipped = soup.find('p', attrs={'id': 'rally_skipped'})
        rally_skipped.string = str(skipped)
        rally_failed = soup.find('p', attrs={'id': 'rally_failed'})
        rally_failed.string = str(failures)
        rally_total = soup.find('p', attrs={'id': 'rally_total'})
        rally_total.string = str(total)
    else:
        logging.warning('Path to the rally results file is wrong')


@check_section('SPT', ['Filepath'], 'Check section "SPT" key "Filepath"')
def process_spt_results():
    """
        Fill in result table with SPT test results
    """
    filename = parser.get('SPT', 'Filepath')
    if os.path.isfile(filename):
        with open(filename, 'r') as file_spt:
            table = soup.find("table", attrs={'id': 'SPTTests'})
            tag_tbody = table.find('tbody', attrs={'id': 'spt_results_tbody'})

            for line in file_spt:
                if line.startswith('------'):
                    break
                tr_id = 'tr_' + _gen_random_str(7)
                tag_tbody.append(soup.new_tag('tr', **{'class': 'c20', 'id': tr_id}))
                tag_tr = table.find('tr', attrs={'id': tr_id})

                td_id = 'td_' + _gen_random_str(7)
                for i in [1, 0]:
                    tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i}))
                    tag_td = table.find('td', attrs={'id': td_id + '%s' % i})
                    tag_td.append(soup.new_tag('p', **{'class': 'font_style_2', 'id': td_id + '%s' % i}))
                    tag_p = table.find('p', attrs={'id': td_id + '%s' % i})
                    tag_p.append(line.split('<--')[i])
    else:
        logging.warning('Path to the SPT results file is wrong')


@check_section('Tempest', ['Filepath'], 'Check section "Tempest" key "Filepath"')
def process_tempest_results():
    """
     Fill in result table with Tempest test results
    """
    tempest_data = parser.get('Tempest', 'Filepath')
    if os.path.isfile(tempest_data):
        with open('%s' % tempest_data) as tempest_results:
            json_data = json.load(tempest_results)
            verifications_id = json_data['verifications'].keys()[0]
            success = json_data['verifications'][verifications_id]['success']
            failures = json_data['verifications'][verifications_id]['failures']
            skipped = json_data['verifications'][verifications_id]['skipped']
            total = success + failures + skipped

        tempest_passed = soup.find('p', attrs={'id': 'tempest_passed'})
        tempest_passed.string = str(success)
        tempest_skipped = soup.find('p', attrs={'id': 'tempest_skipped'})
        tempest_skipped.string = str(skipped)
        tempest_failed = soup.find('p', attrs={'id': 'tempest_failed'})
        tempest_failed.string = str(failures)
        tempest_total = soup.find('p', attrs={'id': 'tempest_total'})
        tempest_total.string = str(total)
    else:
        logging.warning('Path to the tempest results file is wrong')


@check_section('HA', ['Filepath'], 'Check section "HA" key "Filepath"')
def process_ha_results():
    """
     Fill in result table with HA test results
    """
    ha_data_file = parser.get('HA', 'Filepath')
    if os.path.isfile(ha_data_file):
        with open('%s' % ha_data_file) as ha_results:
            json_data = json.load(ha_results)
            success = json_data['passed']
            failures = json_data['failed']
            skipped = json_data['skipped']
            total = success + failures + skipped

        ha_passed = soup.find('p', attrs={'id': 'ha_passed'})
        ha_passed.string = str(success)
        ha_skipped = soup.find('p', attrs={'id': 'ha_skipped'})
        ha_skipped.string = str(skipped)
        ha_failed = soup.find('p', attrs={'id': 'ha_failed'})
        ha_failed.string = str(failures)
        ha_total = soup.find('p', attrs={'id': 'ha_total'})
        ha_total.string = str(total)
    else:
        logging.warning('Path to the HA results file is wrong')


@check_section('OSTF', ['Filepath'], 'Check section "OSTF" key "Filepath"')
def process_ostf_results():
    """
     Fill in result table with OSTF test results
    """
    ostf_data_file = parser.get('OSTF', 'Filepath')
    if os.path.isfile(ostf_data_file):
        with open('%s' % ostf_data_file) as ostf_results:
            json_data = json.load(ostf_results)
            success = json_data['passed']
            failures = json_data['failed']
            skipped = json_data['skipped']
            total = success + failures + skipped

        ostf_passed = soup.find('p', attrs={'id': 'ostf_passed'})
        ostf_passed.string = str(success)
        ostf_skipped = soup.find('p', attrs={'id': 'ostf_skipped'})
        ostf_skipped.string = str(skipped)
        ostf_failed = soup.find('p', attrs={'id': 'ostf_failed'})
        ostf_failed.string = str(failures)
        ostf_total = soup.find('p', attrs={'id': 'ostf_total'})
        ostf_total.string = str(total)
    else:
        logging.warning('Path to the OSTF results file is wrong')


@check_section('Manual', ['Filepath'], 'Check section "Manual" key "Filepath"')
def process_manual_results():
    """
     Fill in result table with manual test results
    """
    manual_data_file = parser.get('Manual', 'Filepath')
    if os.path.isfile(manual_data_file):
        with open('%s' % manual_data_file) as manual_results:
            json_data = json.load(manual_results)
            success = json_data['passed']
            failures = json_data['failed']
            skipped = json_data['skipped']
            total = success + failures + skipped

        manual_passed = soup.find('p', attrs={'id': 'manual_passed'})
        manual_passed.string = str(success)
        manual_skipped = soup.find('p', attrs={'id': 'manual_skipped'})
        manual_skipped.string = str(skipped)
        manual_failed = soup.find('p', attrs={'id': 'manual_failed'})
        manual_failed.string = str(failures)
        manual_total = soup.find('p', attrs={'id': 'manual_total'})
        manual_total.string = str(total)
    else:
        logging.warning('Path to the Manual results file is wrong')


# @check_section('Software', ['SoftwareVersions'], 'Check section "Software" key "SoftwareVersions"')
def software():
    # insert list of used software
    if parser.has_section('Software'):
        _insert_list('software_list', 'Software', 'SoftwareVersions')
    else:
        h3_tag = soup.find('h3', attrs={'id': 'h3_software'})
        h3_tag.decompose()
        p_tag_1 = soup.find('p', attrs={'id': 'p_software_1'})
        p_tag_1.decompose()
        p_tag_2 = soup.find('p', attrs={'id': 'p_software_2'})
        p_tag_2.decompose()


def skipped_failed_tests(section, key):

    if parser.has_option(section, key):
        p_tag = soup.find('p', attrs={'id': section+'_skipped_failed_p'})
        p_tag.append(soup.new_tag('br'))
        p_tag.string = parser.get(section, key)
        p_tag.append(soup.new_tag('br'))
        p_tag.append(soup.new_tag('br'))

    table_tag = soup.find('table', attrs={'id': section+'_skipped_failed_table'})
    tag_tbody = table_tag.find('tbody', attrs={'id': section+'_skipped_failed_tbody'})

    lst = ['Area', 'Test ID & Description', 'Result', 'Comments']
    tr_id = 'tr_' + _gen_random_str(10)
    tag_tbody.append(soup.new_tag('tr', **{'class': 'c38', 'id': tr_id}))
    tag_tr = table_tag.find('tr', attrs={'id': tr_id})
    for item in lst:
        th_id = 'tr_' + _gen_random_str(10)
        tag_tr.append(soup.new_tag('th', **{'class': 'c50', 'id': th_id}))
        tag_th = table_tag.find('th', attrs={'id': th_id})
        tag_th.append(item)

    parser_data = parser.items(section)
    issues_list = [i for i in parser_data if i[0] != 'Description']
    for issue in issues_list:
        tr_id = 'tr_' + _gen_random_str(10)
        tag_tbody.append(soup.new_tag('tr', **{'class': 'c20', 'id': tr_id}))
        tag_tr = table_tag.find('tr', attrs={'id': tr_id})

        td_id = 'td_' + _gen_random_str(10)
        issue_list = issue[1].split('\n')
        for i in range(4):
            # tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i}))
            if str(i) == '0':
                tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                   'style': 'width:30%%; word-break: break-word'}))
            if str(i) == '1':
                tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                   'style': 'width:25%; word-break: break-word'}))
            if str(i) == '2':
                tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                   'style': 'width:10%; word-break: break-word'}))
            if str(i) == '3':
                tag_tr.append(soup.new_tag('td', **{'class': 'c0', 'id': td_id + '%s' % i,
                                                   'style': 'width:35%; word-break: break-word'}))
            tag_td = table_tag.find('td', attrs={'id': td_id + '%s' % i})
            p_id = 'p_' + _gen_random_str(7)
            tag_td.append(soup.new_tag('p', **{'class': 'font_style_2', 'id': p_id}))
            tag_p = table_tag.find('p', attrs={'id': p_id})
            tag_p.append(issue_list[i])


def test_section(function, section, table_id):
    if parser.has_section(section):
        if parser.has_option(section, "TestOwner") and parser.has_option(section, "TestDate"):
            insert_date_and_author('span', 'id', section, 'owner_'+section.lower(), 'date_'+section.lower())
        else:
            p_tag_1 = soup.find('p', attrs={'id': 'p_owner_' + section.lower()})
            p_tag_1.decompose()
            p_tag_2 = soup.find('p', attrs={'id': 'p_date_' + section.lower()})
            p_tag_2.decompose()
        if parser.has_option(section, "Filepath"):
            function
        else:
            p_tag_3 = soup.find('table', attrs={'id': table_id})
            p_tag_3.decompose()
        if parser.has_option(section, "Summary"):
            _paste_text(section, "Summary", section.lower()+"_summary")
        else:
            p_tag = soup.find('p', attrs={'id': section.lower() + '_summary'})
            p_tag.decompose()
        if parser.has_section('SkippedFailed'+section):
            skipped_failed_tests('SkippedFailed'+section, 'Description')
        else:
            p_tag = soup.find('p', attrs={'id':  'SkippedFailed' + section + '_skipped_failed_p'})
            p_tag.decompose()
            table_tag = soup.find('table', attrs={'id': 'SkippedFailed' + section + '_skipped_failed_table'})
            table_tag.decompose()
    else:
        h3_tag = soup.find('h3', attrs={'id': 'h3_' + section.lower()})
        h3_tag.decompose()
        p_tag_1 = soup.find('p', attrs={'id': 'p_owner_' + section.lower()})
        p_tag_1.decompose()
        p_tag_2 = soup.find('p', attrs={'id': 'p_date_' + section.lower()})
        p_tag_2.decompose()
        p_tag_3 = soup.find('table', attrs={'id': table_id})
        p_tag_3.decompose()
        p_tag = soup.find('p', attrs={'id': 'SkippedFailed' + section + '_skipped_failed_p'})
        p_tag.decompose()
        table_tag = soup.find('table', attrs={'id': 'SkippedFailed' + section + '_skipped_failed_table'})
        table_tag.decompose()
        p_tag = soup.find('p', attrs={'id': section.lower() + '_summary'})
        p_tag.decompose()


def main():
    title_page()
    conclusion()

    test_section(process_ostf_results(), "OSTF", 'OSTFHealthCheck')
    test_section(process_tempest_results(), "Tempest", 'TempestTests')
    test_section(process_rally_results(), "Rally", 'RallyTests')
    test_section(process_ha_results(), "HA", 'HATests')
    test_section(process_spt_results(), "SPT", 'SPTTests')
    test_section(process_manual_results(), "Manual", 'ManualTests')

    update_table_four_columns('issues_table', 'issues_table_tbody', 'Issues')
    update_table_four_columns('SolutionTestStatus', 'SolutionTestStatus_tbody', 'SolutionTestStatus')
    update_table_four_columns('TestTools', 'TestTools_tbody', 'TestTools')

    update_table_three_columns('ExitCriteria', 'ExitCriteria_tbody', 'ExitCriteria')

    update_table_two_columns('deployment_overview', 'deployment_overview_tbody', 'DeploymentOverview')
    update_table_two_columns('PluginComponentOverview', 'PluginComponentOverview_tbody', 'PluginComponentOverview')
    update_table_two_columns('CustomerSpecificExtensions', 'CustomerSpecificExtensions_tbody',
                             'CustomerSpecificExtensions')

    software()


if __name__ == "__main__":
    main()

    html_report.close()
    html = soup.prettify("utf-8")
    with open("final_test_report.html", "wb") as tmp_file:
        tmp_file.write(html)
