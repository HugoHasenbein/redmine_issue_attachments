# redmine_issue_attachments
Browse **all issue attachments** of **all issues** in current project in arbitrary queries. Queries can be saved like issue queries. Download bulk pdf attachments as combined pdf's, combined pdf's for double sided printing or as zip archive. Other bulk attachments can be downloaded as zip archives. In zip archives and combined pdf's the order of the selected files adheres to the order in the index list.

![animated GIF that represents a quick overview](/doc/Overview.gif)

### Use case
* Search all invoices from issues and archive them
* Find all images or files of a certain type

### Install 

1. go to your plugins folder

`git clone https://github.com/HugoHasenbein/redmine_issue_attachments.git`

2. install gems

go to Redmine root folder

`bundle install`

3. restart Redmine, f.i.

`/etc/init.d/apache2 restart`

### Uninstall

1. go to your plugins folder

`rm -r redmine_issue_attachments`

2. restart Redmine, f.i.

`/etc/init.d/apache2 restart`

### Use

Make sure you have the right 'View issue attachments' permissions, which can be set in 'Roles and Permissions' in the Redmine Administration menu in the section 'Issue-Attachments'

The 'Issue-Attachments' can be found in the 'Project' menu

### Compatibilties

* Supports Redmine Attachment Categories

### Localisations

* English
* German

### Change.Log

* **1.0.4** added bulk delete, bulk categorize (if Redmine Attachment Categories is installed)
* **1.0.3** minor fixes
* **1.0.2** July 1st commit
