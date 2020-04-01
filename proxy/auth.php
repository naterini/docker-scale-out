<?php
error_reporting(E_ALL);

if (isset($_GET) && isset($_GET['user'])) {
	session_start();
	$_SESSION['user_name'] = $_GET['user'];
	echo "<p>Hello {$_GET['user']}.</p>";

	if (!isset($_GET['token']) || $_GET['token'] == "") {
		unset($_SESSION['user_token']);
		echo "<p>Using slurm user for authentication proxy.</p>";
	} else {
		$_SESSION['user_token'] = $_GET['token'];
		echo "<p>You entered {$_GET['token']} as your token.</p>";
	}
	exit();
}
header('HTTP/1.0 401 Unauthorized');
?>
<html>
<body>
<p>Authentication Options:</p?
<ul>
	<li>Per user token:<ul>
		<li>User: "fred"</li>
		<li>Password: use generated token from scontrol</li>
	</ul></li>
	<li>Authentication Proxy:<ul>
		<li>User: "fred"</li>
		<li>Password: leave empty to use "slurm" user as an authentication proxy.</li>
	</ul></li>
</ul>
<hr>
<p>
<form action="?" method="get">
User name: <input type="text" name="user"><br>
Scontrol Token: <input type="text" name="token"><br>
<input type="submit">
</form>
</p>
</body>
</html>
