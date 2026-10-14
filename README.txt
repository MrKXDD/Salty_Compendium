Setup

1. Start XAMPP. In the XAMPP Control Panel, start Apache and MySQL.

2. Import the database. Open http://localhost/phpmyadmin, go to the Import tab, and import these files in order:

new_salty.sql (this creates the card_marketplace database)
Insert_info_salty_project.sql (mock data, optional)

3. Copy the app. Copy the gachamart folder to C:\xampp\htdocs\gachamart\. It holds three files:

index.html: the front-end
api.php: the whole backend
.htaccess: maps /api/... URLs to api.php

On macOS the path is /Applications/XAMPP/htdocs/, and on Linux it is /opt/lampp/htdocs/.

4. Check the connection settings. At the top of api.php, the defaults are user root, an empty password, and database card_marketplace. These are the XAMPP defaults, so change them only if you set a MySQL password.

5. Test it. First open http://localhost/gachamart/api/dump. You should see JSON with all your tables. Then open http://localhost/gachamart/ for the app. Always use the http://localhost address. Opening the HTML file directly from disk won’t reach the API.

How it works
One read endpoint: api/dump returns every table in one request, with statuses in lowercase and probabilities as percent. The page keeps this as a read-only cache. This is why the Views barely changed.
Writes: each write goes to the API (POST, PUT, DELETE, PATCH on /api/items, /traders, /gachas, /listings and /orders). The page then reloads the dump and redraws. The new act() helper in the Controller does this.
Transactions: spinning a gacha, checkout, and payment each run as a single database transaction with row locks. That stops two people taking the last stock or the same listing.
Cart and “Shopping as”: these stay in the browser’s localStorage, because your schema has no cart table.
Safety: all queries use prepared statements, so SQL injection is not a concern.

Changes from the earlier version
Removed buttons: Load sample data, Import JSON and Reset are gone from the footer, because the database is now the source of truth. Use phpMyAdmin to reset or reload data. Export JSON remains.
Email is required: Trader.Email is NOT NULL UNIQUE in your schema, so the trader form now requires it. A duplicate email gives a clear error message.
Probabilities are percent: the form field is now labelled “Probability (%)”.
Extra statuses: the dropdowns now include refunded and returned, which exist in your mock data.

If something goes wrong
Apache won’t start: port 80 is usually taken by Skype or IIS. Stop that program or change Apache’s port.
404 on /api/dump: .htaccess is being ignored. Check that mod_rewrite is enabled in httpd.conf, and that the folder’s AllowOverride is set to All. XAMPP’s htdocs is set up this way by default.
“Unknown database”: the import in step 2 didn’t run.
Large images: the front-end resizes images, but if uploads fail, raise post_max_size and upload_max_filesize in php.ini.
