<?php
/**
 * Theme functions for Aegean — mbany
 */

if ( ! function_exists( 'aegean_enqueue_assets' ) ) {
	function aegean_enqueue_assets() {
		// Enqueue theme stylesheet
		wp_enqueue_style( 'aegean-style', get_stylesheet_uri(), array(), '1.0' );
	}
	add_action( 'wp_enqueue_scripts', 'aegean_enqueue_assets' );
}

if ( ! function_exists( 'aegean_setup' ) ) {
	function aegean_setup() {
		register_nav_menus( array( 'primary' => __( 'Primary Menu', 'aegean' ) ) );
		add_theme_support( 'title-tag' );
		add_theme_support( 'post-thumbnails' );
	}
	add_action( 'after_setup_theme', 'aegean_setup' );
}

// Allow SVG uploads to the media library (basic safe support)
function aegean_mime_types( $mimes ) {
	$mimes['svg'] = 'image/svg+xml';
	return $mimes;
}
add_filter( 'upload_mimes', 'aegean_mime_types' );

