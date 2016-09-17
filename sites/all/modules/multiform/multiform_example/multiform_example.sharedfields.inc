<?php

/**
 * Sharedfields example page callback.
 */
function multiform_sharedfields_example_page() {
  module_load_include('inc', 'node', 'node.pages');

  // see node_edit().
  // for "edit" option use node_load() and just pass node object into args.
  global $user;

  $type = 'multiform_base';
  $node = (object) array(
    'uid' => $user->uid,
    'name' => (isset($user->name) ? $user->name : ''),
    'type' => $type,
    'language' => LANGUAGE_NONE,
  );
  $node2 = clone $node;
  $node2->type = 'multiform_dependent';

  // prepare multiform settings
  $settings = array(
    '#multiform_id' => 'multiform_sharedfields_example',
    '#subforms' => array(
      array(
        'form_id' => 'multiform_base_node_form',
        'args' => array($node),
      ),
      array(
        'form_id' => 'multiform_dependent_node_form',
        'args' => array($node2),
      ),
    ),
  );

  return multiform_get_form($settings);
}


/**
 * Hide node form additional settings tabs.
 */
function multiform_example_node_form_settings_hide(&$form) {
  // Hide settings groups.
  // http://drupal.stackexchange.com/questions/28758/hide-publishing-options-in-hook-form-alter-without-unpublishing-node
  $groups = array(
    'author' => array('name', 'date'),  // authoring information
    'options' => array('status', 'promote', 'sticky'),  // publishing options
    'comment_settings' => array('comment'), // comments
    'revision_information' => array('revision', 'log'), // revision information
    'path' => array('alias'), // path alias
  );
  foreach ($groups as $k => $group) {
    foreach ($group as $v => $option) {
      $form[$k][$option]['#type'] = 'value';
      $form[$k][$option]['#value'] = $form[$k][$option]['#default_value'];
    }
    $form[$k]['#type'] = 'container';
    $form[$k]['#title'] = '';
  }
  // Just hide menu tab.
  $form['menu']['#access'] = FALSE;
  // Hide node preview button.
  $form['actions']['preview']['#access'] = FALSE;
}

