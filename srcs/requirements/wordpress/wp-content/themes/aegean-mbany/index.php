<?php
/**
 * Main index fallback for the theme.
 */
get_header();

if ( have_posts() ) :
    while ( have_posts() ) : the_post();
        the_content();
    endwhile;
else :
    // If no posts, load front-page template if present
    if ( file_exists( get_template_directory() . '/front-page.php' ) ) {
        include_once get_template_directory() . '/front-page.php';
    } else {
        echo '<main class="container"><h1>' . esc_html__( 'Welcome', 'aegean' ) . '</h1></main>';
    }
endif;

get_footer();
