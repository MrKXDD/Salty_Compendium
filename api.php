<?php
// GachaMart API — PHP + PDO for XAMPP (Apache + MariaDB/MySQL)
// All requests arrive here via .htaccess:  /gachamart/api/xyz  ->  api.php?path=xyz

const DB_HOST = '127.0.0.1';
const DB_NAME = 'card_marketplace';
const DB_USER = 'root';
const DB_PASS = '';            // XAMPP default is an empty password

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

class HttpError extends Exception {}
function fail($code, $msg) { throw new HttpError($msg, $code); }

// ---------- database helpers ----------
function pdo() {
    static $p = null;
    if (!$p) {
        $p = new PDO('mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4', DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
    }
    return $p;
}
function q($sql, $p = []) { $s = pdo()->prepare($sql); $s->execute($p); return $s->fetchAll(); }
function one($sql, $p = []) { $r = q($sql, $p); return $r ? $r[0] : null; }
function run($sql, $p = []) { $s = pdo()->prepare($sql); $s->execute($p); return $s->rowCount(); }
function newId() { return (int) pdo()->lastInsertId(); }
function marks($a) { return implode(',', array_fill(0, count($a), '?')); }
function tx($fn) {
    $db = pdo(); $db->beginTransaction();
    try { $r = $fn(); $db->commit(); return $r; }
    catch (Throwable $e) { $db->rollBack(); throw $e; }
}
function nums($rows, $keys) {          // DECIMAL columns come back as strings -> real numbers
    foreach ($rows as $i => $r) foreach ($keys as $k) if (isset($r[$k])) $rows[$i][$k] = (float) $r[$k];
    return $rows;
}
function out($data, $code = 200) {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PARTIAL_OUTPUT_ON_ERROR);
    exit;
}
function s($v) { $v = trim((string) ($v ?? '')); return $v === '' ? null : $v; }   // '' -> NULL

// UI uses lower-case words, DB uses ENUM labels
const PAY_UI2DB  = ['pending' => 'Pending', 'paid' => 'Success', 'failed' => 'Failed', 'refunded' => 'Refunded'];
const SHIP_UI2DB = ['preparing' => 'Preparing', 'shipped' => 'Shipped', 'delivered' => 'Delivered', 'returned' => 'Returned'];

// ---------- tiny router ----------
$routes = [];
function route($method, $regex, $fn) { global $routes; $routes[] = [$method, '#^' . $regex . '$#', $fn]; }

$method = $_SERVER['REQUEST_METHOD'];
$path   = '/' . trim($_GET['path'] ?? '', '/');
$body   = json_decode(file_get_contents('php://input'), true) ?: [];

// =====================================================================
//  GET /dump  — everything the front-end needs, in one request
// =====================================================================
route('GET', '/dump', function () {
    $d = [];
    $d['traders']   = q('SELECT Trader_ID id, Trader_Name name, Email email, Phone phone, Address address FROM Trader ORDER BY Trader_ID');
    $d['items']     = q('SELECT Item_ID id, ItemName name, ItemType item_type, Series series, Description description, Listing_ID listing_id FROM Items ORDER BY Item_ID');
    $d['cards']     = q('SELECT Item_ID item_id, Rarity rarity, CardType card_type FROM Card');
    $d['boxsets']   = q('SELECT Item_ID item_id, ReleaseDate release_date, TotalCards total_cards FROM Boxset');
    $d['gachas']    = nums(q('SELECT Gacha_ID id, Name name, LOWER(Status) status, Price price, Stock stock FROM Gacha ORDER BY Gacha_ID'), ['price']);
    $d['listings']  = nums(q('SELECT Listing_ID id, Trader_ID trader_id, Order_ID order_id, price FROM Listing ORDER BY Listing_ID'), ['price']);
    $d['orders']    = nums(q('SELECT Order_ID id, Trader_ID trader_id, DATE(orderDate) order_date, total_amount, LOWER(Status) status FROM Orders ORDER BY Order_ID'), ['total_amount']);
    $pay = nums(q('SELECT Order_ID order_id, LOWER(payment_status) payment_status, amount, DATE(payment_date) payment_date, method FROM Payment'), ['amount']);
    foreach ($pay as $i => $p) if ($p['payment_status'] === 'success') $pay[$i]['payment_status'] = 'paid';
    $d['payments']  = $pay;
    $d['shipments'] = q('SELECT Order_ID order_id, courier_name, tracking_no, LOWER(status) status, address FROM Shipment');
    $d['own']       = q('SELECT Trader_ID trader_id, Item_ID item_id, quantity FROM Own');
    $d['includes']  = nums(q('SELECT Gacha_ID gacha_id, Item_ID item_id, ROUND(probability*100,2) probability FROM Includes'), ['probability']);
    $d['opens']     = q('SELECT Open_ID id, Trader_ID trader_id, Gacha_ID gacha_id, Item_ID result_item, date_opened FROM `Open` ORDER BY Open_ID');
    return $d;
});

// =====================================================================
//  Traders
// =====================================================================
route('POST', '/traders', function ($m, $b) {
    if (!s($b['name'] ?? null) || !s($b['email'] ?? null)) fail(400, 'Name and email are required.');
    run('INSERT INTO Trader (Trader_Name,Email,Phone,Address) VALUES (?,?,?,?)',
        [s($b['name']), s($b['email']), s($b['phone'] ?? null), s($b['address'] ?? null)]);
    return ['id' => newId()];
});
route('PUT', '/traders/(\d+)', function ($m, $b) {
    if (!s($b['name'] ?? null) || !s($b['email'] ?? null)) fail(400, 'Name and email are required.');
    run('UPDATE Trader SET Trader_Name=?,Email=?,Phone=?,Address=? WHERE Trader_ID=?',
        [s($b['name']), s($b['email']), s($b['phone'] ?? null), s($b['address'] ?? null), $m[1]]);
    return ['ok' => true];
});
route('DELETE', '/traders/(\d+)', function ($m) {
    tx(function () use ($m) {
        run('DELETE FROM Own WHERE Trader_ID=?', [$m[1]]);
        run('DELETE FROM `Open` WHERE Trader_ID=?', [$m[1]]);
        run('DELETE FROM Trader WHERE Trader_ID=?', [$m[1]]);     // FK error -> 409 + rollback if listings/orders exist
    });
    return ['ok' => true];
});
route('POST', '/traders/(\d+)/own', function ($m, $b) {          // manual "add item to inventory"
    $qty = max(1, (int) ($b['quantity'] ?? 1));
    run('INSERT INTO Own (Trader_ID,Item_ID,quantity) VALUES (?,?,?) ON DUPLICATE KEY UPDATE quantity=quantity+VALUES(quantity)',
        [$m[1], (int) ($b['item_id'] ?? 0), $qty]);
    return ['ok' => true];
});

// =====================================================================
//  Items (supertype) + Card / Boxset (subtypes)
// =====================================================================
function writeSubtype($id, $f) {
    if ($f['item_type'] === 'Card') {
        run('INSERT INTO Card (Item_ID,ItemType,Rarity,CardType) VALUES (?,?,?,?)',
            [$id, 'Card', s($f['rarity'] ?? null) ?? '-', s($f['card_type'] ?? null) ?? '-']);
    } else {
        run('INSERT INTO Boxset (Item_ID,ItemType,ReleaseDate,TotalCards) VALUES (?,?,?,?)',
            [$id, 'Boxset', s($f['release_date'] ?? null), max(1, (int) ($f['total_cards'] ?? 1))]);
    }
}
function checkItem($f) {
    if (!s($f['name'] ?? null)) fail(400, 'Item name is required.');
    if (!in_array($f['item_type'] ?? '', ['Card', 'Boxset'], true)) fail(400, 'Type must be Card or Boxset.');
}
route('POST', '/items', function ($m, $b) {
    checkItem($b);
    return ['id' => tx(function () use ($b) {
        run('INSERT INTO Items (Listing_ID,ItemType,ItemName,Series,Description) VALUES (NULL,?,?,?,?)',
            [$b['item_type'], s($b['name']), s($b['series'] ?? null), s($b['description'] ?? null)]);
        $id = newId();
        writeSubtype($id, $b);
        return $id;
    })];
});
route('PUT', '/items/(\d+)', function ($m, $b) {
    checkItem($b);
    tx(function () use ($m, $b) {
        run('DELETE FROM Card WHERE Item_ID=?', [$m[1]]);          // subtype row must go before ItemType may change
        run('DELETE FROM Boxset WHERE Item_ID=?', [$m[1]]);
        run('UPDATE Items SET ItemType=?,ItemName=?,Series=?,Description=? WHERE Item_ID=?',
            [$b['item_type'], s($b['name']), s($b['series'] ?? null), s($b['description'] ?? null), $m[1]]);
        writeSubtype((int) $m[1], $b);
    });
    return ['ok' => true];
});
route('DELETE', '/items/(\d+)', function ($m) {
    $it = one('SELECT Listing_ID FROM Items WHERE Item_ID=?', [$m[1]]);
    if (!$it) fail(404, 'Item not found.');
    if ($it['Listing_ID']) fail(409, 'Cannot delete: this item is referenced by a listing.');
    tx(function () use ($m) {
        run('DELETE FROM Own WHERE Item_ID=?', [$m[1]]);
        run('DELETE FROM Includes WHERE Item_ID=?', [$m[1]]);
        run('DELETE FROM Card WHERE Item_ID=?', [$m[1]]);
        run('DELETE FROM Boxset WHERE Item_ID=?', [$m[1]]);
        run('DELETE FROM Items WHERE Item_ID=?', [$m[1]]);         // 409 if gacha history (Open) still points at it
    });
    return ['ok' => true];
});

// =====================================================================
//  Gacha machines
// =====================================================================
function gachaFields($b) {
    if (!s($b['name'] ?? null)) fail(400, 'Machine name is required.');
    return [s($b['name']), ($b['status'] ?? '') === 'active' ? 'Active' : 'Inactive',
            max(0, (float) ($b['price'] ?? 0)), max(0, (int) ($b['stock'] ?? 0))];
}
route('POST', '/gachas', function ($m, $b) {
    [$n, $st, $pr, $sk] = gachaFields($b);
    run('INSERT INTO Gacha (Name,Status,Price,Stock) VALUES (?,?,?,?)', [$n, $st, $pr, $sk]);
    return ['id' => newId()];
});
route('PUT', '/gachas/(\d+)', function ($m, $b) {
    [$n, $st, $pr, $sk] = gachaFields($b);
    run('UPDATE Gacha SET Name=?,Status=?,Price=?,Stock=? WHERE Gacha_ID=?', [$n, $st, $pr, $sk, $m[1]]);
    return ['ok' => true];
});
route('DELETE', '/gachas/(\d+)', function ($m) {
    tx(function () use ($m) {
        run('DELETE FROM Includes WHERE Gacha_ID=?', [$m[1]]);
        run('DELETE FROM `Open` WHERE Gacha_ID=?', [$m[1]]);
        run('DELETE FROM Gacha WHERE Gacha_ID=?', [$m[1]]);
    });
    return ['ok' => true];
});
route('PUT', '/gachas/(\d+)/includes/(\d+)', function ($m, $b) {  // body.probability is a PERCENT (0-100); DB stores 0-1
    $frac = min(1, max(0.0001, ((float) ($b['probability'] ?? 1)) / 100));
    run('INSERT INTO Includes (Gacha_ID,Item_ID,probability) VALUES (?,?,?) ON DUPLICATE KEY UPDATE probability=VALUES(probability)', [$m[1], $m[2], $frac]);
    return ['ok' => true];
});
route('DELETE', '/gachas/(\d+)/includes/(\d+)', function ($m) {
    run('DELETE FROM Includes WHERE Gacha_ID=? AND Item_ID=?', [$m[1], $m[2]]);
    return ['ok' => true];
});

// Spin — one transaction: lock machine, check stock, random draw, log it, give item to trader
route('POST', '/gachas/(\d+)/open', function ($m, $b) {
    $gid = (int) $m[1]; $tid = (int) ($b['trader_id'] ?? 0);
    if (!one('SELECT 1 FROM Trader WHERE Trader_ID=?', [$tid])) fail(400, 'Choose who is spinning.');
    $won = tx(function () use ($gid, $tid) {
        $g = one('SELECT Status, Stock FROM Gacha WHERE Gacha_ID=? FOR UPDATE', [$gid]);   // row lock: last stock can't be spent twice
        if (!$g || $g['Status'] !== 'Active') fail(400, 'This gacha machine is not active.');
        if ((int) $g['Stock'] <= 0)           fail(400, 'This gacha machine is out of stock.');
        $pool = q('SELECT Item_ID, probability FROM Includes WHERE Gacha_ID=?', [$gid]);
        if (!$pool) fail(400, 'This gacha machine has no items yet.');
        $total = 0; foreach ($pool as $p) $total += (float) $p['probability'];
        $r = mt_rand() / mt_getrandmax() * $total; $win = end($pool)['Item_ID'];
        foreach ($pool as $p) { $r -= (float) $p['probability']; if ($r <= 0) { $win = $p['Item_ID']; break; } }
        run('UPDATE Gacha SET Stock=Stock-1 WHERE Gacha_ID=?', [$gid]);
        run('INSERT INTO `Open` (Trader_ID,Gacha_ID,Item_ID) VALUES (?,?,?)', [$tid, $gid, $win]);
        run('INSERT INTO Own (Trader_ID,Item_ID,quantity) VALUES (?,?,1) ON DUPLICATE KEY UPDATE quantity=quantity+1', [$tid, $win]);
        return $win;
    });
    return one('SELECT Item_ID id, ItemName name FROM Items WHERE Item_ID=?', [$won]);
});

// =====================================================================
//  Listings
// =====================================================================
route('POST', '/listings', function ($m, $b) {
    $tid = (int) ($b['trader_id'] ?? 0); $price = (float) ($b['price'] ?? 0);
    $ids = array_values(array_unique(array_map('intval', $b['item_ids'] ?? [])));
    if ($price <= 0) fail(400, 'Price must be greater than 0.');
    if (!$ids)       fail(400, 'Pick at least one item to sell.');
    return ['id' => tx(function () use ($tid, $price, $ids) {
        // only items the seller owns that are not tied to an unsold listing
        $ok = q('SELECT o.Item_ID FROM Own o JOIN Items i ON i.Item_ID=o.Item_ID
                 LEFT JOIN Listing l ON l.Listing_ID=i.Listing_ID
                 WHERE o.Trader_ID=? AND o.quantity>0 AND o.Item_ID IN (' . marks($ids) . ')
                   AND (i.Listing_ID IS NULL OR l.Order_ID IS NOT NULL) FOR UPDATE', array_merge([$tid], $ids));
        if (!$ok) fail(400, 'Pick at least one item the seller owns that is not already listed.');
        $okIds = array_column($ok, 'Item_ID');
        run('INSERT INTO Listing (Trader_ID,Order_ID,price) VALUES (?,NULL,?)', [$tid, $price]);
        $lid = newId();
        run('UPDATE Items SET Listing_ID=? WHERE Item_ID IN (' . marks($okIds) . ')', array_merge([$lid], $okIds));
        return $lid;
    })];
});
route('DELETE', '/listings/(\d+)', function ($m) {
    tx(function () use ($m) {
        $l = one('SELECT Order_ID FROM Listing WHERE Listing_ID=? FOR UPDATE', [$m[1]]);
        if (!$l) fail(404, 'Listing not found.');
        if ($l['Order_ID']) fail(409, 'This listing has already been ordered.');
        run('UPDATE Items SET Listing_ID=NULL WHERE Listing_ID=?', [$m[1]]);
        run('DELETE FROM Listing WHERE Listing_ID=?', [$m[1]]);
    });
    return ['ok' => true];
});

// =====================================================================
//  Orders / Payment / Shipment
// =====================================================================
// Payment success: items move seller -> buyer (runs inside the caller's transaction)
function settle($oid) {
    $p = one('SELECT payment_status FROM Payment WHERE Order_ID=? FOR UPDATE', [$oid]);
    if (!$p || $p['payment_status'] === 'Success') return;
    $o = one('SELECT Trader_ID FROM Orders WHERE Order_ID=?', [$oid]);
    run("UPDATE Payment SET payment_status='Success', payment_date=NOW() WHERE Order_ID=?", [$oid]);
    run("UPDATE Orders SET Status='Paid' WHERE Order_ID=?", [$oid]);
    $moves = q('SELECT l.Trader_ID seller, i.Item_ID item FROM Listing l JOIN Items i ON i.Listing_ID=l.Listing_ID WHERE l.Order_ID=?', [$oid]);
    foreach ($moves as $mv) {
        // Own has CHECK(quantity>0): remove the row instead of letting it hit 0
        run('DELETE FROM Own WHERE Trader_ID=? AND Item_ID=? AND quantity<=1', [$mv['seller'], $mv['item']]);
        run('UPDATE Own SET quantity=quantity-1 WHERE Trader_ID=? AND Item_ID=? AND quantity>1', [$mv['seller'], $mv['item']]);
        run('INSERT INTO Own (Trader_ID,Item_ID,quantity) VALUES (?,?,1) ON DUPLICATE KEY UPDATE quantity=quantity+1', [$o['Trader_ID'], $mv['item']]);
    }
}
route('POST', '/orders', function ($m, $b) {                     // checkout
    $buyer = (int) ($b['buyer_id'] ?? 0);
    $ids = array_values(array_unique(array_map('intval', $b['listing_ids'] ?? [])));
    if (!$buyer || !$ids) fail(400, 'Your cart has no available listings.');
    return ['id' => tx(function () use ($b, $buyer, $ids) {
        $ls = q('SELECT Listing_ID, price FROM Listing WHERE Listing_ID IN (' . marks($ids) . ')
                 AND Order_ID IS NULL AND Trader_ID<>? FOR UPDATE', array_merge($ids, [$buyer]));   // lock: no double-buying
        if (!$ls) fail(400, 'Your cart has no available listings.');
        $total = 0; foreach ($ls as $l) $total += (float) $l['price'];
        run("INSERT INTO Orders (Trader_ID,total_amount,Status) VALUES (?,?,'Pending')", [$buyer, $total]);
        $oid = newId(); $lids = array_column($ls, 'Listing_ID');
        run('UPDATE Listing SET Order_ID=? WHERE Listing_ID IN (' . marks($lids) . ')', array_merge([$oid], $lids));
        run('INSERT INTO Payment (Order_ID,amount,method) VALUES (?,?,?)', [$oid, $total, s($b['method'] ?? null)]);
        run('INSERT INTO Shipment (Order_ID,address) VALUES (?,?)', [$oid, s($b['address'] ?? null)]);
        if (!empty($b['pay_now'])) settle($oid);
        return $oid;
    })];
});
route('PATCH', '/orders/(\d+)/payment', function ($m, $b) {
    $status = PAY_UI2DB[$b['status'] ?? ''] ?? null;
    if (!$status) fail(400, 'Unknown payment status.');
    tx(function () use ($m, $status) {
        $p = one('SELECT payment_status FROM Payment WHERE Order_ID=? FOR UPDATE', [$m[1]]);
        if (!$p) fail(404, 'Order not found.');
        if ($p['payment_status'] === 'Success') { if ($status === 'Success') return; fail(400, 'A paid order cannot be changed here.'); }
        if ($status === 'Success') return settle($m[1]);
        run('UPDATE Payment SET payment_status=? WHERE Order_ID=?', [$status, $m[1]]);
        if ($status === 'Failed' || $status === 'Refunded') run("UPDATE Orders SET Status='Cancelled' WHERE Order_ID=?", [$m[1]]);
    });
    return ['ok' => true];
});
route('PATCH', '/orders/(\d+)/shipment', function ($m, $b) {
    $status = SHIP_UI2DB[$b['status'] ?? ''] ?? null;
    if (!$status) fail(400, 'Unknown shipment status.');
    tx(function () use ($m, $b, $status) {
        run('UPDATE Shipment SET courier_name=?,tracking_no=?,status=? WHERE Order_ID=?', [s($b['courier_name'] ?? null), s($b['tracking_no'] ?? null), $status, $m[1]]);
        if ($status === 'Shipped')   run("UPDATE Orders SET Status='Shipped' WHERE Order_ID=? AND Status='Paid'", [$m[1]]);
        if ($status === 'Delivered') run("UPDATE Orders SET Status='Completed' WHERE Order_ID=?", [$m[1]]);
    });
    return ['ok' => true];
});

// ---------- dispatch ----------
try {
    foreach ($routes as [$mth, $re, $fn]) {
        if ($mth === $method && preg_match($re, $path, $mm)) out($fn($mm, $body));
    }
    fail(404, 'Unknown API route: ' . $method . ' ' . $path);
} catch (HttpError $e) {
    out(['error' => $e->getMessage()], $e->getCode());
} catch (PDOException $e) {
    $n = $e->errorInfo[1] ?? 0;
    if ($n == 1451) out(['error' => 'Cannot delete: other records still reference this row.'], 409);
    if ($n == 1062) out(['error' => 'That value is already used (e.g. the email belongs to another trader).'], 409);
    if ($n == 4025 || $n == 3819) out(['error' => 'A value broke a database rule (e.g. price must be greater than 0).'], 400);
    out(['error' => 'Database error: ' . $e->getMessage()], 500);
} catch (Throwable $e) {
    out(['error' => 'Server error: ' . $e->getMessage()], 500);
}
