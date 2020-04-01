<?php
error_reporting(E_ALL);
session_start();

if (session_status() == PHP_SESSION_NONE || !isset($_SESSION['user_name'])) {
	header("HTTP/1.1 401 Unauthorized");
} else {
	// default to loading the slurm user token
	if (!isset($_SESSION['user_token']) || $_SESSION['user_token'] == "") {
		$_SESSION['user_token'] = file_get_contents("/auth/slurm");
	}

	header("X-SLURM-USER-NAME: ".$_SESSION['user_name']);
	header("X-SLURM-USER-TOKEN: ".$_SESSION['user_token']);
}

?>
