<?php
/**
 * @file
 * Install, update and uninstall functions for the createsite installation profile.
 */

/**
 * Implements hook_form_alter().
 *
 * Allows the profile to alter the site configuration form.
 */
function createsite_form_install_configure_form_alter(&$form, $form_state) {
  // Set a default site name and email address.
  $form['site_information']['site_name']['#default_value']= t('Hackrobats Installation Profile');
  $form['site_information']['site_mail']['#default_value']= 'support@hackrobats.net';

  // Set a default username and email address.
  $form['admin_account']['account']['name']['#default_value']= 'hackrobats';
  $form['admin_account']['account']['mail']['#default_value']= 'maintenance@hackrobats.net';

  // Set a default country and timezone.
  $form['server_settings']['site_default_country']['#default_value']= 'US';
  $form['server_settings']['date_default_timezone']['#default_value']= 'America/Los_Angeles';

  // Disable the 'receive email notifications' check box.
  $form['update_notifications']['update_status_module']['#default_value'][1] = 0;
}
