<?php

/**
 * Return sharedfields info for given multiform.
 *
 * @todo
 * Store sharedfields info in multiform settings.
 */
function multiform_sharedfields_info($multiform) {
  // @todo: Consider the case of multiple multiforms with sharedfields
  // on the same page.
  static $stored_info = array();
  if (!isset($stored_info[$multiform['#multiform_id']])) {
    $stored_info[$multiform['#multiform_id']] = array();

    // Invoke hook_multiform_sharedfields()
    // Modules should return only items for a given multiform_id
    $items = module_invoke_all('multiform_sharedfields', $multiform);
    foreach ($items as $item) {
      $base_index = $item['#base']['#tag'];
      $dependent_index = $item['#dependent']['#tag'];
      if ($base_index && $dependent_index) {
        $item['#base']['#index'] = $base_index;
        $item['#dependent']['#index'] = $dependent_index;
        $stored_info[$multiform['#multiform_id']][] = $item;
      }
    }
  }

  return $stored_info;
}


/**
 * Set values for sharedfields based on $_POST array.
 */
function multiform_sharedfields_set_post_values($multiform, $sharedfields_info) {
  if (!empty($_POST) && isset($multiform['#multiform_id']) && isset($sharedfields_info[$multiform['#multiform_id']])) {
    $multiform_id = $multiform['#multiform_id'];
    foreach ($sharedfields_info[$multiform_id] as $item) {
      // Get array path to the element in $_POST.
      $parents_base = $item['#base']['#parents'];
      array_unshift($parents_base, 'multiform', $item['#base']['#index']);
      // Get base value
      $key_exists = NULL;
      $value = drupal_array_get_nested_value($_POST, $parents_base, $key_exists);
      // If base key exist in $_POST array, set dependent value.
      if ($key_exists) {
        $parents_dependent = $item['#dependent']['#parents'];
        array_unshift($parents_dependent, 'multiform', $item['#dependent']['#index']);
        drupal_array_set_nested_value($_POST, $parents_dependent, $value, TRUE);
      }
    }
  }
}


/**
 * Hide dependent sharedfields.
 */
function multiform_sharedfields_hide_elements($multiform, $sharedfields_info, &$form, $form_state) {
  if (isset($form_state['#subform_index'])) {
    $multiform_id = $multiform['#multiform_id'];
    $subform_index = $form_state['#subform_index'];
    if (isset($sharedfields_info[$multiform_id])) {
      foreach ($sharedfields_info[$multiform_id] as $item) {
        if ($item['#dependent']['#index'] == $subform_index) {
          $array_parents_dependent = $item['#dependent']['#array_parents'];
          if (drupal_array_nested_key_exists($form, $array_parents_dependent)) {
            array_push($array_parents_dependent, '#pre_render');
            $pre_render = drupal_array_get_nested_value($form, $array_parents_dependent);
            if (is_array($pre_render)) {
              $pre_render[] = 'multiform_sharedfields_pre_render';
            }
            else {
              $pre_render = array('multiform_sharedfields_pre_render');
            }
            drupal_array_set_nested_value($form, $array_parents_dependent, $pre_render, TRUE);
          }
        }
      }
    }
  }
}


/**
 * Mark dependent sharedfields as rendered.
 */
function multiform_sharedfields_pre_render($element) {
  $element['#printed'] = TRUE;
  return $element;
}

