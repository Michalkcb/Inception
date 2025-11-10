<?php
/**
 * Template to display comments and comment form for the aegean-mbany theme.
 */

if ( post_password_required() ) {
    return;
}

?>
<section id="comments" class="section">
    <div class="container">
        <h2><?php echo esc_html( get_comments_number() ? sprintf( _n( '%s komentarz', '%s komentarze', get_comments_number(), 'aegean' ), number_format_i18n( get_comments_number() ) ) : 'Komentarze' ); ?></h2>

        <?php if ( have_comments() ) : ?>
            <ol class="comment-list">
                <?php
                wp_list_comments( array(
                    'style'      => 'ol',
                    'short_ping' => true,
                    'avatar_size'=> 48,
                ) );
                ?>
            </ol>
        <?php else : ?>
            <p class="no-comments"><?php esc_html_e( 'Brak komentarzy. Bądź pierwszy.', 'aegean' ); ?></p>
        <?php endif; ?>

        <?php
        // If comments are closed, display a note.
        if ( ! comments_open() ) :
            echo '<p class="comments-closed">' . esc_html__( 'Komentarze są zamknięte.', 'aegean' ) . '</p>';
        else :
            // Display comment form
            $comment_form_args = array(
                'title_reply' => __( 'Dodaj komentarz', 'aegean' ),
                'label_submit' => __( 'Wyślij komentarz', 'aegean' ),
                'comment_field' => '<p class="comment-form-comment"><label for="comment">' . _x( 'Komentarz', 'noun' ) . '</label><textarea id="comment" name="comment" cols="45" rows="6" required></textarea></p>',
            );
            comment_form( $comment_form_args );
        endif;
        ?>
    </div>
</section>
